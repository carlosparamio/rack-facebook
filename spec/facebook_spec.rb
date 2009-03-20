require 'rack/request'
require 'rack/mock'
require 'rack/facebook'

describe Rack::Facebook do
  SECRET = "123456789"
  API_KEY = "616313"
  
  def calculate_signature(hash)
    raw_string = hash.map{ |*pair| pair.join('=') }.sort.join
    Digest::MD5.hexdigest([raw_string, SECRET].join)
  end
  
  def sign_hash(hash, prefix)
    fb_hash = hash.inject({}) do |all, (key, value)|
      all[key.sub("#{prefix}_", "")] = value if key.index("#{prefix}_") == 0
      all
    end
    hash.merge(prefix => calculate_signature(fb_hash))
  end
  
  def sign_params(hash)
    sign_hash(hash, "fb_sig")
  end
  
  def sign_cookies(hash)
    sign_hash(hash, API_KEY)
  end
  
  def post_env(params)
    env = {"rack.request.form_hash" => params}
    env["rack.request.form_input"] = env["rack.input"] = "fb"
    env
  end
  
  def post(app, params)
    mock_post app, post_env(params)
  end
  
  def mock_post(app, env)
    facebook = described_class.new(app, :application_secret => SECRET, :api_key => API_KEY)
    request = Rack::MockRequest.new(facebook)
    @response = request.post("/", env)
  end
  
  def cookie_env(cookies)
    env = {"rack.request.cookie_hash" => cookies}
    env["rack.request.cookie_string"] = env["HTTP_COOKIE"] = "fb"
    env
  end
  
  def cookie_request(app, cookies)
    mock_post app, cookie_env(cookies)
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
      
      it "should split friend IDs into an array" do
        app = lambda do |env|
          env["facebook.friends"].should == ["2", "3", "5"]
          response_env
        end
        post app, sign_params("fb_sig_friends" => "2,3,5")
        response.status.should == 200
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
    
    context "cookie authentication" do
      it "should run app if cookie signature is valid" do
        app = mock('rack app')
        app.should_receive(:call).with(instance_of(Hash)).and_return(response_env)
        cookie_request app, sign_cookies("#{API_KEY}_user" => "22", "#{API_KEY}_ss" => "SEKRIT")
        response.status.should == 200
      end
      
      it "should not run app if cookie signature turns out invalid" do
        cookie_request mock('rack app'), API_KEY => "INVALID", "#{API_KEY}_ss" => "SEKRIT"
        response.status.should == 400
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
