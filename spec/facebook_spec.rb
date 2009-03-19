require 'rack/request'
require 'rack/mock'
require 'rack/facebook'

describe Rack::Facebook do
  SECRET = "123456789"
  
  def calculate_signature(hash)
    raw_string = hash.map{ |*pair| pair.join('=') }.sort.join
    Digest::MD5.hexdigest([raw_string, SECRET].join)
  end
  
  def sign_params(hash)
    fb_hash = hash.inject({}) do |all, (key, value)|
      all[key.sub("fb_sig_", "")] = value if key.index("fb_sig_") == 0
      all
    end
    hash.merge("fb_sig" => calculate_signature(fb_hash))
  end
  
  def post_env(params)
    {"rack.request.form_hash" => params, "rack.request.form_input" => "fb", "rack.input" => "fb"}
  end
  
  def post(app, params)
    request = Rack::MockRequest.new(described_class.new(app, SECRET))
    @response = request.post("/", post_env(params))
  end
  
  def response
    @response
  end
  
  def response_env(status = 200)
    [status, {"Content-type" => "test/plain", "Content-length" => "5"}, ["hello"]]
  end
  
  describe 'without a block' do
    describe 'when the fb_sig is not valid' do
      it 'should return 400 Invalid Facebook signature' do
        post mock('rack app'), "fb_sig" => "INVALID"
        response.status.should == 400
      end
    end
    
    describe 'when the fb_sig is valid' do
      it 'should convert the facebook parameters to ruby objects' do
        app = lambda do |env|
          @env = env
          @params = Rack::Request.new(env).params
          response_env
        end
        
        post app, sign_params("fb_sig_in_canvas" => "1", "fb_sig_time" => "1")
        response.status.should == 200
        
        @params['fb_sig'].should be_nil
        @params['fb_sig_time'].should be_nil
        @env['facebook.time'].should == Time.at(1)
        @env['facebook.in_canvas'].should be_true
      end
      
      it 'should convert the request method from POST to the original client method' do
        app = mock('rack app')
        app.should_receive(:call).with { |env|
          env['REQUEST_METHOD'].should == 'PUT'
          env['facebook.original_method'].should == 'POST'
          true
        }.and_return(response_env)
        post app, sign_params("fb_sig_request_method" => "PUT")
      end

      it 'should run app' do
        app = mock('rack app')
        app.should_receive(:call).with(instance_of(Hash)).and_return(response_env)
        post app, sign_params("fb_sig_foo" => "bar")
      end
    end
  end

  describe 'with a block' do
    describe 'when the block returns a value that evaluates to true' do
      it 'should execute the middleware'
    end
    describe 'when the block returns a value that evaluates to true' do
      it 'should skip the middleware'
    end
  end
end
