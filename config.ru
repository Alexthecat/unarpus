use Rack::Static,
  :urls => ["/images", "/img", "/js", "/css"],
  :root => "public"

require './conf/newprod'

run App.new