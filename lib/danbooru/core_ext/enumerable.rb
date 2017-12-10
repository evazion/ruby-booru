module Enumerable
  def +(other)
    concat(other)
  end

  def concat(*others)
    [self, *others].flat_map { |e| e.to_a }
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

class Enumerator::Lazy
  def concat(*others)
    [self, *others].lazy.flat_map { |e| e.lazy }
  end
end
