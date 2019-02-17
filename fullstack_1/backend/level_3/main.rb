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
        @milestones = []
        @error = [] # if there is an error in any method, add it here
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

    def getZeroIndexedTarget(target, start = @start)
        target - start
    end

    def getZeroIndexedValue(value, start = @start)
        value - start
    end

    def getValueFromZeroIndexedValue(z_value, start = @start)
        z_value + start
    end

    def getTotalDays(start_date, end_date)
        (end_date - start_date).to_i
    end

    def getValueFromPercent(percent, start_value, target_value)
        z_index_value = percent  * getZeroIndexedTarget(target_value, start_value)
        value = getValueFromZeroIndexedValue(z_index_value, start_value)
        return value
    end

    def getPercentOfPeriod(date, start_date, end_date)
        total_period_in_days = getTotalDays(start_date, end_date)
        period_in_days = (date - start_date).to_i
        percent = period_in_days.to_f / total_period_in_days
        return percent
    end

    def getSupposedProgressAtDate(date, start_date, end_date, start_value, target_value)
        period_percentage = getPercentOfPeriod(date, start_date, end_date)
        supposed_value = getValueFromPercent(period_percentage, start_value, target_value)
        return supposed_value
    end

    def getExcess(value, date)
        start_date = @start_date
        end_date = @end_date
        start_value = @start
        target_value = @target
        milestone_modifier = 0
        milestone_before = getMilestoneJustBefore(date)
        if milestone_before
            start_date = milestone_before[:date]
            start_value = milestone_before[:target]
        end
        milestone_after = getMilestoneJustAfter(date)
        if milestone_after
            end_date = milestone_after[:date]
            target_value = milestone_after[:target]
        end
        supposed_value = getSupposedProgressAtDate(date, start_date, end_date, start_value, target_value)
        zero_indexed_supposed_value = getZeroIndexedValue(supposed_value, start_value)
        
        zero_indexed_real_value = getZeroIndexedValue(value, start_value)
        if milestone_before
            milestone_modifier = getZeroIndexedValue(milestone_before[:target])
        end
        difference_percentage = ((zero_indexed_real_value + milestone_modifier) / (zero_indexed_supposed_value + milestone_modifier)).round(2) - 1
        return (100 * difference_percentage).to_i
    end

    def getMilestoneJustBefore(date)
        milestone_before = false
        @milestones.each { |milestone| 
                            if (date - milestone[:date]).to_i > 0
                                milestone_before = milestone
                            end
                        }
        return milestone_before
    end

    def getMilestoneJustAfter(date)
        milestone_after = false
        reversed_milestones = @milestones.reverse
        reversed_milestones.each { |milestone| 
                            if (milestone[:date] - date).to_i > 0
                                milestone_after = milestone
                            end
                        }
        return milestone_after
    end

    def addMilestone(milestone_obj)
        point = {:date => Date.parse(milestone_obj["date"]), :target => milestone_obj["target"]}
        @milestones.push(point)
        @milestones.sort! { |a, b| a[:date] <=> b[:date]}
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

input["milestones"].each { |milestone_data| 
                objective_id = milestone_data["objective_id"]
                objective = objectives.detect { |objective| objective.getId == objective_id}
                if objective
                    objective.addMilestone(milestone_data)
                end
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

output_progress_records.sort! { |a, b| a[:id] <=> b[:id] }

output = {:progress_records => output_progress_records}
output_json = JSON.pretty_generate output

file = File.open("data/output.json", "w"){ |f| f << output_json}
file.close