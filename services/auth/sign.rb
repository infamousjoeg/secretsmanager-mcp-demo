require "jwt"
require "sinatra"

JWT_SIGNING_SECRET = "supersecretjwt-please-change-before-prod"

post "/token" do
  content_type :json
  username = params[:username]
  payload = { sub: username, iat: Time.now.to_i, exp: Time.now.to_i + 3600 }
  token = JWT.encode(payload, JWT_SIGNING_SECRET, "HS256")
  { token: token }.to_json
end

get "/verify" do
  token = request.env["HTTP_AUTHORIZATION"].to_s.sub(/^Bearer /, "")
  decoded, _header = JWT.decode(token, JWT_SIGNING_SECRET, true, algorithm: "HS256")
  content_type :json
  { sub: decoded["sub"] }.to_json
end
