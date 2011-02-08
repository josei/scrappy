require 'monitor'

module Scrappy
  module Cached
    def self.included base
      base.extend Cached::ClassMethods
    end

    module ClassMethods
      def cache
        @cache ||= Cache.new
      end
    end
    
    def cache
      self.class.cache
    end
  end

  class Cache < Hash
    include MonitorMixin
    
    def expire! timeout
      synchronize do
        keys.each { |req| delete(req) if Time.now.to_i - self[req][:time].to_i > timeout }
      end
    end

    def []= key, value
      synchronize { super }
    end

    def [] key
      synchronize { super }
    end
  end
end