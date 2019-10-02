module ReportPortal
  module Cucumber
    # @api private
    class DataTableFormatter
      class << self
        def format_table(table)
          column_sizes = table.transpose.raw.map do |column_row|
            column_row.max_by(&:size).size
          end
          str = ''
          table.raw.each do |row|
            texts = row.map.with_index do |text, column_index|
              text.ljust(column_sizes[column_index])
            end
            str << "| #{texts.join(' | ')} |\n"
          end
          str
        end
      end
    end
  end
end
