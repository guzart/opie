require 'spec_helper'

RSpec.describe Opie::Failure do
  context '::new' do
    it 'assigns the first argument to #data' do
      failure = Opie::Failure.new(:exception)
      expect(failure.data).to eq(:exception)
    end
  end
end
