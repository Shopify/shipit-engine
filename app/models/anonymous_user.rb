class AnonymousUser
  def email
    'anonymous@example.com'
  end

  def login
    'anonymous'
  end

  def name
    'Anonymous'
  end

  def id
  end

  def logged_in?
    false
  end

  def stacks_contributed_to
    []
  end
end
