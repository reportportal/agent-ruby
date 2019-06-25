require 'pathname'

RSpec.describe 'top level', :ui do
  it 'passes and logs a string and an image', tag1: :value do
    RSpec.configuration.reporter.message("multiline\nstring")

    image = Pathname(__FILE__).dirname.parent + 'assets' + 'crane.png'
    RSpec.configuration.reporter.message(image)
  end

  it 'fails' do
    fail 'error'
  end

  it 'is pending' do
    pending('reason 1')
    fail 'error to make it failed as expected'
  end

  it 'marked as pending but actually it passes' do
    pending
  end

  context 'context' do
    it 'is nested' do
    end

    context 'nested context' do
      it 'is nested twice' do
        fail 'error'
      end
    end
  end
end
