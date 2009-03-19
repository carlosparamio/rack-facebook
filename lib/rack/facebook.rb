require 'digest'

module Rack
  # This Rack middleware checks the signature of Facebook params, and
  # converts them to Ruby objects when appropiate. Also, it converts
  # the request method from the Facebook POST to the original HTTP
  # method used by the client.
  #
  # If the signature is wrong, it returns a "400 Invalid Facebook Signature".
  # 
  # Optionally, it can take a block that receives the Rack environment
  # and returns a value that evaluates to true when we want the middleware to
  # be executed for the specific request.
  #
  # == Usage
  #
  # In your config.ru:
  #
  #   require 'rack/facebook'
  #   use Rack::Facebook, "my_facebook_secret_key"
  #
  # Using a block condition:
  #
  #   use Rack::Facebook, "my_facebook_secret_key" do |env|
  #     env['REQUEST_URI'] =~ /^\/facebook_only/
  #   end
  #
  class Facebook    
    def initialize(app, secret_key, &condition)
      @app = app
      @secret = secret_key
      @condition = condition
    end
    
    def call(env)
      request = Rack::Request.new(env)
      
      if facebook_request?(request)
        fb_params = extract_facebook_params(request.POST)
        
        if signature_is_valid?(fb_params, request.POST.delete("fb_sig"))
          env["facebook.original_method"] = env["REQUEST_METHOD"]
          env["REQUEST_METHOD"] = fb_params.delete("request_method")
          save_facebook_params(fb_params, env)
        else
          return [400, {"Content-Type" => "text/html"}, ["Invalid Facebook signature"]]
        end
      end
      return @app.call(env)
    end
    
    private
    
    def facebook_request?(request)
      (@condition.nil? or @condition.call(request.env)) and request.POST["fb_sig"]
    end
    
    def signature_is_valid?(fb_params, actual_sig)
      actual_sig == calculate_signature(fb_params)
    end
    
    def calculate_signature(hash)
      raw_string = hash.map{ |*pair| pair.join('=') }.sort.join
      Digest::MD5.hexdigest([raw_string, @secret].join)
    end
    
    def extract_facebook_params(params)
      params.inject({}) do |fb, (key, _)|
        fb[key.sub(/^fb_sig_/, '')] = params.delete(key) if key.index("fb_sig_")
        fb
      end
    end
    
    def save_facebook_params(params, env)
      params.each do |key, value|
        ruby_value = case key
        when 'added', 'in_canvas', 'in_new_facebook', 'position_fix'
          value == '1'
        when 'expires', 'profile_update_time', 'time'
          begin
            Time.at(value.to_f) rescue TypeError

          rescue TypeError
            # oh noes!
          end
        when 'friends'
          value.split(',')
        end
            
        env["facebook.#{key}"] = ruby_value if ruby_value
      end
    end
  end
end