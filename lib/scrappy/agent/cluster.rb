module Cluster

  def self.included(klass)
    klass.extend ClassMethods
    klass.extend MonitorMixin
  end

  def consume(list, results, args={})
    begin
      element = list.synchronize { list.pop }
      unless element.nil?
        result = process(element, args)
        results.synchronize { results << result }
      end
    end until element.nil?
  end

  module ClassMethods
    def cluster; @cluster; end
    def cluster= value; @cluster=value; end

    def create_cluster count, *args
      self.cluster = (1..count).map { args.nil? ? create : create(*args) }
    end

    def process(list=[], args={})
      results = []
      list.extend MonitorMixin
      results.extend MonitorMixin
      cluster.map { |o| Thread.new { o.consume(list, results, args) } }.each { |t| t.join }
      results
    end
  end

end
