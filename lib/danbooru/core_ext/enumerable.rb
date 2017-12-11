module Enumerable
  # http://www.dogbiscuit.org/mdub/weblog/Tech/Programming/Ruby/MultiThreadedProcessingWithLazyEnumerables
  def pmap(workers: 1, &block)
    return lazy.map(&block) if workers <= 1
    block = lambda { |x| x } unless block_given?

    threads = lazy.map { |element| Thread.new { block.call(element) } }
    values = threads.prefetch(workers - 1).map(&:value)
    values
  end

  def prefetch(size = 0, &block)
    return enum_for(:prefetch, size, &block) unless block_given?
    return each(&block) if size <= 0

    buffer = []
    each_with_index do |element, i|
      yield buffer.shift if i >= size
      buffer << element
    end

    buffer.each(&block)
  end

  def to_dtext(headers = nil)
    headers ||= [first.to_h.keys.map(&:capitalize)]
    rows = map(&:to_h).map(&:values)

    <<~DTEXT
      [table]
        [thead]
      #{rows_to_dtext(headers, tag: "th")}
        [/thead]
        [tbody]
      #{rows_to_dtext(rows, tag: "td")}
        [/tbody]
      [/table]
    DTEXT
  end

  private
  def rows_to_dtext(rows, tag: "td", indent: 4)
    rows.map do |row|
      cols = row.map do |col|
        spaces = " " * (indent + 2)
        "#{spaces}[#{tag}] #{col} [/#{tag}]\n"
      end.join

      spaces = " " * indent
      "#{spaces}[tr]\n#{cols}#{spaces}[/tr]\n"
    end.reduce("", &:+).chop # join("\n")
  end
end
