require 'json'
require 'date'

class Range
    def reverse
        r = dup
        def r.each(&block)
            last.downto(first, &block)
        end
        r
    end
end

class Objective
    def initialize(id, start, target, start_date, end_date)
        @id, @start, @target, @start_date, @end_date = id, start, target, start_date, end_date
    end

    def getId
        @id
    end

    def getStart
        @start
    end

    def getTarget
        @target
    end

    def getStart_date
        @start_date
    end

    def getEnd_date
        @end_date
    end

    def getZeroIndexedTarget()
        @target - @start
    end

    def getZeroIndexedValue(value)
        value - @start
    end

    def getValueFromZeroIndexedValue(z_value)
        z_value + @start
    end

    def getTotalDays()
        (@end_date - @start_date).to_i
    end

    def getValueFromPercent(percent)
        z_index_value = percent  * getZeroIndexedTarget()
        value = getValueFromZeroIndexedValue(z_index_value)
        return value
    end

    def getPercentOfPeriod(date)
        total_period_in_days = getTotalDays()
        period_in_days = (date - @start_date).to_i
        percent = period_in_days.to_f / total_period_in_days
        return percent
    end

    def getSupposedProgressAtDate(date)
        period_percentage = getPercentOfPeriod(date)
        supposed_value = getValueFromPercent(period_percentage)
        return supposed_value
    end

    def getExcess(value, date)
        supposed_value = getSupposedProgressAtDate(date)
        zero_indexed_supposed_value = getZeroIndexedValue(supposed_value)
        zero_indexed_real_value = getZeroIndexedValue(value)
        difference_percentage = (zero_indexed_real_value / zero_indexed_supposed_value) -1
        return (difference_percentage.round(2) * 100).to_i
    end

end

json = File.read('data/input.json')
input = JSON.parse(json)

objectives = []
input_progress_demands = input["progress_records"]

output_progress_records = []

input["objectives"].each { |objective_data|
                    id = objective_data["id"]
                    start = objective_data["start"]
                    target = objective_data["target"]
                    start_date = Date.parse(objective_data["start_date"])
                    end_date = Date.parse(objective_data["end_date"])
                    objectives.push(Objective.new(id, start, target, start_date, end_date))
                }

objectives.each { |objective|
                id = objective.getId
                progress = input_progress_demands.detect { |progress| progress["objective_id"] == id}
                if progress
                    value = progress["value"]
                    date = Date.parse(progress["date"])
                    output_progress_records.push({"id": progress["id"], "excess": objective.getExcess(value, date)})
                end
            }

output_progress_records.sort! { |a, b| a[:id] <=> b[:id]}


output = {:progress_records => output_progress_records}
output_json = JSON.pretty_generate output
            
file = File.open("data/output.json", "w"){ |f| f << output_json}
file.close