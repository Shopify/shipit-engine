module PayloadsHelper

  def payload(name)
    file = Rails.root.join('test/fixtures/payloads', "#{name}.json")
    JSON.parse(file.read)
  end

end
