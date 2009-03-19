require 'digest'
require 'rack/request'

module Rack
  # This Rack middleware checks the signature of Facebook params and
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
  # In your rack builder:
  #
  #   use Rack::Facebook, :application_secret => "SECRET", :api_key => "APIKEY"
  #
  # Using a block condition:
  #
  #   use Rack::Facebook, options do |env|
  #     env['REQUEST_URI'] =~ /^\/facebook_only/
  #   end
  #
  class Facebook    
    def initialize(app, options, &condition)
      @app = app
      @options = options
      @condition = condition
    end
    
    def secret
      @options[:application_secret]
    end
    
    def api_key
      @options[:api_key]
    end
    
    def call(env)
      request = Request.new(env, api_key)
      
      if passes_condition?(request) and request.facebook?
        valid = true
        
        if request.params_signature
          fb_params = request.extract_facebook_params(:post)
        
          if valid = valid_signature?(fb_params, request.params_signature)
            env["facebook.original_method"] = env["REQUEST_METHOD"]
            env["REQUEST_METHOD"] = fb_params.delete("request_method")
            save_facebook_params(fb_params, env)
          end
        elsif request.cookies_signature
          cookie_params = request.extract_facebook_params(:cookies)
          valid = valid_signature?(cookie_params, request.cookies_signature)
        end
        
        unless valid
          return [400, {"Content-Type" => "text/html"}, ["Invalid Facebook signature"]]
        end
      end
      return @app.call(env)
    end
    
    private
    
    def passes_condition?(request)
      @condition.nil? or @condition.call(request.env)
    end
    
    def valid_signature?(fb_params, actual_sig)
      actual_sig == calculate_signature(fb_params)
    end
    
    def calculate_signature(hash)
      raw_string = hash.map{ |*pair| pair.join('=') }.sort.join
      Digest::MD5.hexdigest([raw_string, secret].join)
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
    
    class Request < ::Rack::Request
      FB_PREFIX = "fb_sig".freeze
      
      def initialize(env, api_key)
        super(env)
        @api_key = api_key
      end
      
      def facebook?
        params_signature or cookies_signature
      end
      
      def params_signature
        return @params_signature if @params_signature or @params_signature == false
        @params_signature = self.POST.delete(FB_PREFIX) || false
      end

      def cookies_signature
        cookies[@api_key]
      end
      
      def extract_facebook_params(where)
        case where
        when :post
          source = self.POST
          prefix = FB_PREFIX
        when :cookies
          source = cookies
          prefix = @api_key
        end
        
        prefix = "#{prefix}_"
        
        source.inject({}) do |extracted, (key, value)|
          extracted[key.sub(prefix, '')] = value if key.index(prefix) == 0
          source.delete(key) if :post == where
          extracted
        end
      end
    end
  end
end