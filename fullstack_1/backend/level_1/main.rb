require 'json'

class Range
    def reverse
        r = dup
        def r.each(&block)
            last.downto(first, &block)
        end
        r
    end
end

def createRange(range_start, range_end)
    if range_start < range_end
        range = Range.new(range_start, range_end, true).to_a
     elsif range_start > range_end
        range = Range.new(range_end + 1, range_start).reverse.to_a
    else
        range = range_start
    end
return range
end

def getPercentage(start_value, end_value, current_value)
    range = createRange start_value, end_value
    total_length = range.length
    index = range.index(current_value)
    percentage = (index.to_f / total_length.to_f) * 100
    return percentage.ceil
end

json = File.read('data/input.json')
input = JSON.parse(json)

objectives = input["objectives"]
input_progress_records = input["progress_records"]

output_progress_records = []

objectives.each { |objective|
                    id = objective["id"]
                    start = objective["start"]
                    target = objective["target"]
                    progress = input_progress_records.detect { |progress| progress["objective_id"] == id}
                    if progress
                        output_progress_records.push({"id": progress["id"], "progress": getPercentage(start, target, progress["value"])})
                    end
                }

output_progress_records.sort! { |a, b| a[:id] <=> b[:id]}


output = {:progress_records => output_progress_records}
output_json = JSON.pretty_generate output

file = File.open("data/output.json", "w"){ |f| f << output_json}
file.close
