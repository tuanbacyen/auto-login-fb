require "httparty"
require "json"

x = HTTParty.get(
  "http://localhost:3000/api/v1/accounts/list",
  headers: { "Content-Type" => "application/json", "Authorization" => "bearer 123456789009876543211"}
)

datas = JSON.parse(x.body)["data"]
datas.map do |data|
  attributes = data["attributes"]
  {
    username: attributes["account_fb"]["username"],
    password: attributes["account_fb"]["pwd"],
    group_url: attributes["group"]["group_url"]
  }
end
