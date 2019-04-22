# frozen_string_literal: true
require_relative "test_helper"

SingleCov.covered!

describe RubyCliDaemon do
  it "has a VERSION" do
    RubyCliDaemon::VERSION.must_match /^[\.\da-z]+$/
  end
end
