require 'thread'
require 'monitor'

module MapReduce

  class Queue
    def initialize
      @items = []
      @items.extend MonitorMixin
    end
    
    def pop
      yielded = false
      item = nil
      @items.synchronize do
        item = @items.shift
        if @items.empty?
          yield item if (block_given? and item)
          yielded = true
        end
      end
      yield item if (block_given? and not yielded)
      item
    end
    
    def << value
      @items << value
    end
    
    def push value
      self << value
    end

    def empty?
      @items.synchronize { @items.empty? }
    end
  end

  
  def cluster
    @cluster ||= (1..@cluster_count || 1).map { self.class.new(*(@cluster_options || [])) }
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
      queue.pop do |item|
        result = map item, queue
        results.synchronize { results << result }
      end
    end until queue.empty?
  end

end
