# typed: false
module LinksHelper
  LINKS_PATTERN = /\<(.*?)\>; rel="(\w+)"/

  def assert_link(rel, url)
    assert_includes response_links, rel
    assert_equal url, response_links[rel], %(rel="#{rel}" is incorrect)
  end

  def assert_no_link(rel)
    assert_nil response_links[rel], %(expected rel="#{rel}" to be nil)
  end

  private

  def response_links
    @response_links ||= begin
      links = response.headers['Link'].to_s
      links.scan(LINKS_PATTERN).map(&:reverse).to_h
    end
  end
end
