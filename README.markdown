[![Gem Version](https://badge.fury.io/rb/rack-facebook.svg)](http://badge.fury.io/rb/rack-facebook)

This Rack middleware checks the signature of Facebook params, and
converts them to Ruby objects when appropiate. Also, it converts
the request method from the Facebook POST to the original HTTP
method used by the client.

If the signature is wrong, it returns a "400 Invalid Facebook Signature".

Optionally, it can take a block that receives the Rack environment
and returns a value that evaluates to true when we want the middleware to
be executed for the specific request.

# Usage

In your config.ru:

    require 'rack/facebook'
    use Rack::Facebook, :app_name => "My Application", :application_secret => "SECRET", :api_key => "APIKEY"

Using a block condition:

    use Rack::Facebook, "my_facebook_secret_key" do |env|
      env['REQUEST_URI'] =~ /^\/facebook_only/
    end

# Credits

Carlos Paramio

[http://h1labs.com/](http://h1labs.com/)

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/carlosparamio/rack-facebook/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

