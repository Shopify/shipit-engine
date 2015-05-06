module PayloadsHelper
  def payload(name)
    file = Shipster::Engine.root.join('test/fixtures/payloads', "#{name}.json")
    JSON.parse(file.read)
  end
end
