require File.dirname(__FILE__) + '/../spec_helper'

#class Bosh::Agent::Message::CamelCasedMessageHandler
#  def self.process(args)
#  end
#end

describe Bosh::Agent::Handler do 

  before(:each) do
    @redis = mock("redis")
    Redis.stub(:new).and_return(@redis)

    logger = mock('logger')
    logger.stub!(:info)
    Bosh::Agent::Config.logger = logger
  end

  # FIXME: break more stuff out of the redis subscribe or see if we can enhance
  # http://github.com/causes/modesty.git mock-redis to include pubsub.
  #

  it "should result in a value payload" do
    handler = Bosh::Agent::Handler.new
    payload = handler.process(Bosh::Agent::Message::Ping, nil)
    payload.should == {:value => "pong"}
  end

  it "should result in an exception payload" do
    handler = Bosh::Agent::Handler.new

    klazz = Class.new do
      def self.process(args)
        raise Bosh::Agent::MessageHandlerError, "boo!"
      end
    end
    payload = handler.process(klazz, nil)
    payload.should == {:exception => "#<Bosh::Agent::MessageHandlerError: boo!>"}
  end

  it "should process long running tasks" do
    handler = Bosh::Agent::Handler.new

    klazz = Class.new do 
      def self.process(args)
        "result"
      end
      def self.long_running?; true; end
    end

    agent_task_id = nil
    @redis.should_receive(:publish) do |message_id, payload|
      message_id.should == "bogus_message_id"
      msg = Yajl::Parser.new.parse(payload)
      agent_task_id = msg["value"]["agent_task_id"]
    end
    handler.process_long_running("bogus_message_id", klazz, nil)

    @redis.should_receive(:publish) do |message_id, payload|
      msg = Yajl::Parser.new.parse(payload)
      msg.should == {"value" => "result"}
    end
    handler.handle_get_task("another_bogus_id", agent_task_id)
  end

  it "should have running state for long running task"

  it "should support CamelCase message handler class names" do
    ::Bosh::Agent::Message::CamelCasedMessageHandler = Class.new do
      def self.process(args); end
    end
    handler = Bosh::Agent::Handler.new
    handler.processors.keys.should include("camel_cased_message_handler")
  end

end
