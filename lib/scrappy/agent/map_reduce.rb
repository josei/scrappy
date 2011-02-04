require 'thread'
require 'monitor'

module MapReduce

  class Queue
    include MonitorMixin
    
    def initialize
      super
      @items   = []
      @history = []
    end
    
    def pop
      yielded = false
      item = nil
      synchronize do
        item = @items.shift
        @history << item
        if @items.empty?
          yield item if (block_given? and item)
          yielded = true
        end
      end
      yield item if (block_given? and not yielded)
      item
    end
    
    def << value
      push value
    end
    
    def push value
      synchronize { @items << value }
    end

    def push_unless_done value
      synchronize { @items << value unless @history.include?(value) }
    end
    
    def empty?
      synchronize { @items.empty? }
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
