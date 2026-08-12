# frozen_string_literal: true

module Shipit
  class DeploySpec
    # A DeploySpec::FileSystem that reads files straight out of the git object
    # database instead of a working-tree checkout.
    #
    # It is constructed with an *empty* temporary directory. Every disk access
    # in the spec evaluation code funnels through exactly two seams of the
    # parent class: +file+ (framework discovery probes and config candidates)
    # and +read_config+ (the +inherit_from+ chain). Both are overridden here
    # to materialize the requested path from `git cat-file` into the temporary
    # directory *before* returning, so callers' subsequent +exist?+/+read+
    # calls behave exactly as they would against a full checkout.
    #
    # Whenever byte-identical behavior with a checkout cannot be guaranteed
    # (symlinks, submodules, .gitattributes in an ancestor directory, paths
    # escaping the repository, runaway inherit_from chains), FallbackRequired
    # is raised and the caller is expected to fall back to the checkout-based
    # code path.
    #
    # Unlike the checkout path (which clones a snapshot first), reads target
    # the stack's live git cache. A concurrent ClearGitCacheJob or git gc
    # degrades to a command failure, which the caller treats as a fallback;
    # since every read is pinned to a single commit sha there is no torn-read
    # hazard.
    class GitObjectFileSystem < FileSystem
      class FallbackRequired < StandardError
        attr_reader :reason, :detail

        def initialize(reason, detail = nil)
          @reason = reason
          @detail = detail
          super("#{reason}: #{detail}")
        end
      end

      MAX_INHERIT_READS = 10
      GLOB_CHARS = /[*?\[]/
      TREE_MODE = '040000'
      SYMLINK_MODE = '120000'
      GITLINK_MODE = '160000'

      def initialize(app_dir, stack, commands:, sha:)
        super(app_dir, stack)
        @root = @app_dir.cleanpath
        @commands = commands
        @sha = sha
        @listings = {}
        @materialized = Set.new
        @inherit_reads = 0
        @inherit_chain = []
      end

      def file(path, root: false)
        pathname = super
        if path.to_s.match?(GLOB_CHARS)
          dir = repo_rel(pathname.dirname)
          validate_dir!(dir)
          pattern = File.basename(path.to_s)
          entries(dir).each_key do |name|
            next unless File.fnmatch(pattern, name)

            materialize(dir.empty? ? name : File.join(dir, name))
          end
        else
          materialize(repo_rel(pathname))
        end
        pathname
      end

      private

      # The inherit_from seam. The parent class's build_config checks
      # inherits_from_path.exist? BEFORE calling read_config, so interception
      # must happen here: resolve the reference the same way the parent is
      # about to (path.dirname.join(value)), validate containment, bound the
      # chain, and materialize -- then let the parent proceed against a real
      # file. The old checkout-based path is uncapped (a cycle loops forever)
      # and follows escaping paths onto the worker filesystem; both are hard
      # fallbacks here.
      def build_config(path, config_obj, depth = 0)
        if config_obj.present? && config_obj.key?(SHIPIT_CONFIG_INHERIT_FROM_KEY)
          @inherit_reads += 1
          raise FallbackRequired.new(:inherit_depth, @inherit_chain.join(' -> ')) if @inherit_reads > MAX_INHERIT_READS

          inherits_from = path.dirname.join(config_obj[SHIPIT_CONFIG_INHERIT_FROM_KEY])
          key = repo_rel(inherits_from)
          @inherit_chain << key
          materialize(key)
        end
        super
      end

      # Containment validation. Inputs are always tmpdir-absolute Pathnames
      # (both seams receive resolved paths). Returns the canonical
      # repo-relative key ("" for the root itself, no leading "./", no
      # trailing "/"). The tmpdir was created by us, so @root is canonical
      # and symlink-free; cleanpath-based prefix containment is sufficient
      # and requires no filesystem access.
      def repo_rel(pathname)
        clean = Pathname(pathname).cleanpath
        string = clean.to_s
        root = @root.to_s
        raise FallbackRequired.new(:escape, string) unless string == root || string.start_with?("#{root}/")

        string == root ? "" : string[(root.length + 1)..]
      end

      # Single choke point: every file access materializes here or is
      # provably absent at the commit. Idempotent per instance.
      def materialize(key)
        return if @materialized.include?(key)

        case blob_mode(key)
        when :absent, TREE_MODE
          # Absent at this commit, or a directory itself: nothing to write.
          @materialized << key
        when SYMLINK_MODE
          # `git cat-file` on a symlink returns the link target *text* as if
          # it were file content. Never serve that.
          raise FallbackRequired.new(:symlink, key)
        when GITLINK_MODE
          raise FallbackRequired.new(:submodule, key)
        else
          content = @commands.git_read_object(@sha, key)
          target = @root.join(key)
          target.dirname.mkpath
          File.binwrite(target, content)
          @materialized << key
        end
      end

      # Walks the path's directory components (validating each one) and
      # returns the final component's git mode, or :absent.
      def blob_mode(key)
        parts = key.split('/')
        prefix = ""
        parts[0...-1].each do |component|
          mode = entries(prefix)[component]
          path_so_far = prefix.empty? ? component : "#{prefix}/#{component}"
          case mode
          when nil
            return :absent
          when TREE_MODE
            prefix = path_so_far
          when SYMLINK_MODE
            raise FallbackRequired.new(:symlink, path_so_far)
          when GITLINK_MODE
            raise FallbackRequired.new(:submodule, path_so_far)
          else # a regular file as an intermediate path component
            raise FallbackRequired.new(:file_in_path, path_so_far)
          end
        end

        (parts.last && entries(prefix)[parts.last]) || :absent
      end

      # The glob branch lists a directory without materializing a file, so the
      # directory's own path components must be validated explicitly:
      # `git ls-tree <sha> -- '<dir>/'` on a symlinked directory or on a
      # regular file returns an empty listing with exit 0, which would
      # silently diverge from Dir[] on a checkout (which follows symlinks).
      def validate_dir!(dir)
        return if dir.empty?

        case blob_mode(dir)
        when TREE_MODE, :absent
          nil
        when SYMLINK_MODE
          raise FallbackRequired.new(:symlink, dir)
        when GITLINK_MODE
          raise FallbackRequired.new(:submodule, dir)
        else
          raise FallbackRequired.new(:file_in_path, dir)
        end
      end

      # Memoized directory listings, keyed by canonical repo-relative dir
      # ("" = root). Any listed ancestor containing a .gitattributes entry
      # forces a fallback: a checkout applies eol/text/smudge attributes,
      # `git cat-file` emits raw bytes, and attributes affecting a path can
      # only live in its ancestor directories -- which are exactly the ones
      # we list. A .gitattributes in an unrelated subtree never triggers this.
      def entries(dir)
        @listings[dir] ||= begin
          listing = @commands.git_ls_dir(@sha, dir)
          if listing.key?('.gitattributes')
            raise FallbackRequired.new(:gitattributes, dir.empty? ? '<root>' : dir)
          end

          listing
        end
      end
    end
  end
end
