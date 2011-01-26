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
    MAX_ELEMENTS = 100
    
    def expire! timeout
      synchronize do
        keys.each { |key| delete(key) if Time.now.to_i - self[key][:time].to_i > timeout }
        sort_by { |key, value| value[:time].to_i }[0...size-MAX_ELEMENTS].each { |key, value| delete key } if size > MAX_ELEMENTS
        self
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