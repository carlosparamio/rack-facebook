require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rack/facebook'

describe Rack::Facebook do
  describe 'without a block' do
    describe 'when the fb_sig is not valid' do
      it 'should return 400 Invalid Facebook signature'
    end
    
    describe 'when the fb_sig is valid' do
      it 'should convert the facebook parameters to Ruby objects'
      
      it 'should convert the request method from POST to the original client method'

      it 'should run app'
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
