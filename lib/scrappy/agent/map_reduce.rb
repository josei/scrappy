require 'thread'

module MapReduce

  def self.included(klass)
    klass.send :attr_accessor, :cluster
  end

  def create_cluster count, *args
    self.cluster = [self] + (2..count).map { self.class.new(*args) }
  end

  def process list
    results = []
    results.extend MonitorMixin
    
    queue = Queue.new
    list.each { |element| queue << element }
    
    cluster.map { |obj| Thread.new { obj.work queue, results } }.each { |t| t.join }
    
    reduce results
  end

  def work queue, results
    begin
      result = map queue.pop, queue
      results.synchronize { results << result }
    end until queue.empty?
  end

end
