require 'resque_delay/serializable_method'
require 'resque_delay/message_sending'

Object.send(:include, ResqueDelay::MessageSending)   
Module.send(:include, ResqueDelay::MessageSending::ClassMethods)
