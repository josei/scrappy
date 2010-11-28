require 'thread'

module MapReduce

  def cluster
    @cluster ||= [self] + (2..@cluster_count || 1).map { self.class.new(*(@cluster_options || [])) }
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
