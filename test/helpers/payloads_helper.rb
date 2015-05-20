module PayloadsHelper
  def payload(name)
    file = Shipit::Engine.root.join('test/fixtures/payloads', "#{name}.json")
    JSON.parse(file.read)
  end
end
