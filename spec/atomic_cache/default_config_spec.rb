# frozen_string_literal: true

require 'spec_helper'

describe 'DefaultConfig' do
  subject { DefaultConfig }

  context '#configure' do
    it 'configures the singleton' do
      subject.configure do |manager|
        manager.namespace = 'foo'
      end

      expect(subject.instance.namespace).to eq('foo')
    end
  end
end
