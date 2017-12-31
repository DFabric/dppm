require "kemal"

class Server
  get "/api/is-active/:service" do |env|
    service = env.params.url["service"]
    # if Shell::Seq.run(Env.).success?
    #  env.response.status_code = 200
    #  "good #{INIT}"
    # else
    #  env.response.status_code = 503
    #  "bad #{INIT}"
    # end
  end

  post "/" do
    "create something"
  end

  put "/" do
    "replace something"
  end

  patch "/" do
    "modify something"
  end

  delete "/" do
    "annihilate something"
  end
end
