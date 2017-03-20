require 'spec_helper'

RSpec.describe Opie::Failure do
  context '::new' do
    it 'assigns the first argument to #type' do
      failure = Opie::Failure.new(:exception)
      expect(failure.type).to eq(:exception)
    end

    it 'assigns the second argument to #data' do
      failure = Opie::Failure.new(:oops, 'something important')
      expect(failure.data).to eq('something important')
    end

    it 'requires a type argument' do
      expect { Opie::Failure.new }.to raise_error(ArgumentError)
    end

    it 'does not require a data argument' do
      expect { Opie::Failure.new(:oops) }.not_to raise_error
    end

    it 'defaults #data to nil' do
      failure = Opie::Failure.new(:oops)
      expect(failure.data).to be_nil
    end
  end

  it 'compares Failures by thier type and data' do
    one = Opie::Failure.new(:oops, 'bad error')
    two = Opie::Failure.new(:oops, 'bad error')
    three = Opie::Failure.new(:oops, 'really bad error')

    expect(one).to eq(two)
    expect(one).not_to eq(three)
  end

  it 'generate a hash based on its type and data' do
    one = Opie::Failure.new(:oops, 'bad error')
    two = Opie::Failure.new(:oops, 'bad error')

    expect(one.hash).to eq(two.hash)
  end
end
