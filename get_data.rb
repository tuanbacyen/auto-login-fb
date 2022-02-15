require "httparty"
require "json"

x = HTTParty.get(
  "http://localhost:3000/api/v1/accounts/list",
  headers: { "Content-Type" => "application/json", "Authorization" => "bearer 123456789009876543211"}
)

datas = []
JSON.parse(x.body)["datas"].each do |data|
  datas << {
    username: data[1]["username"],
    password: data[1]["pwd"],
    groups: data[1]["groups"].map{ |i| i["group_url"] }
  }
end

datas
