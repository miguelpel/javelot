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
    def initialize(id, start=nil, target=nil, start_date=nil, end_date=nil, parent_id=nil, coef=nil)
        @id = id
        if start
            @start = start
        end
        if target
            @target = target
        end
        if start_date
            @start_date = Date.parse(start_date)
        end
        if end_date
            @end_date = Date.parse(end_date)
        end
        if parent_id
            @parent_id = parent_id
        end
        if coef
            @coef = coef
        end
        @milestones = []
        @children = []
        @error = nil # if there is an error in any method, add it here
    end

    def getId
        @id
    end

    def getStart
        start = 0
        if @start
            start = @start
        elsif @children.length > 0
            mean_divider = 0
            start_total = 0
            @children.each { |child|
            mean_divider += child.getCoef
            start_total += child.getStart * child.getCoef
            }
            start = start_total / mean_divider
        end
        return start
    end

    def getTarget
        target = 0
        if @target
            target = @target
        elsif @children.length > 0
            mean_divider = 0
            target_total = 0
            @children.each { |child|
            mean_divider += child.getCoef
            target_total += child.getTarget * child.getCoef
            }
            target = target_total / mean_divider
        end
        return target
    end

    def getStart_date
        start_date = 0
        if @start_date
            start_date = @start_date
        elsif @children.length > 0
            ## get the oldest start_date of children
            start_dates = []
            @children.each { |child|
            start_dates.push(child.getStart_date)
            }
            start_dates.sort! { |a, b| a <=> b}
            start_date = start_dates[0]
        end
        return start_date
    end

    def getEnd_date
        end_date = 0
        if @end_date
            end_date = @end_date
        elsif @children.length > 0
            ## get the newer end_date of children
            end_dates = []
            @children.each { |child|
            end_dates.push(child.getEnd_date)
            }
            end_dates.sort! { |a, b| b <=> a}
            end_date = end_dates[0]
        end
        return end_date
    end

    def getParent_id
        @parent_id
    end

    def getCoef
        @coef
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

    def getTheoreticalAchievementAt(date)
        start_date = getStart_date
        end_date = getEnd_date
        start_value = getStart
        target_value = getTarget
        if @milestones.length > 0
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
        end
        supposed_value = getSupposedProgressAtDate(date, start_date, end_date, start_value, target_value)
        return supposed_value
    end

    def getTheoreticalMeanAt(date)
        theoretical_mean = 0
        if @children.length > 0
            mean_divider = 0
            theoretical_total = 0
            @children.each { |child|
            mean_divider += child.getCoef
            theoretical_total += child.getTheoreticalMeanAt(date) * child.getCoef 
            }
            theoretical_mean = theoretical_total / mean_divider
        else
            theoretical_mean = getTheoreticalAchievementAt(date)
        end
        return theoretical_mean
    end

    def getExcess(value, date, process_id)
        if (date - getStart_date).to_i < 0 || (getEnd_date - date).to_i < 0
            @error = ArgumentError.new('Date of process record with id: ' + process_id.to_s + ' outside of scope.')
        end
        mean_start = getStart
        mean_target = getTarget
        if value < [mean_start, mean_target].sort[0] || value > [mean_start, mean_target].sort { |a, b| b <=> a}[0]
            @error = ArgumentError.new('Value of process record with id: ' + process_id.to_s + ' outside of scope.')
        end
        theoretical_mean = getTheoreticalMeanAt(date)
        decimal_difference_mean = ((value - mean_start) / (theoretical_mean - mean_start)).round(2) - 1
        percentage_difference_mean = (decimal_difference_mean * 100).round
        if @error
            raise @error
        else
            return percentage_difference_mean
        end
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

    def addChild(objective_obj)
        @children.push(objective_obj)
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
start_date = objective_data["start_date"]
end_date = objective_data["end_date"]
parent_id = objective_data["parent_id"]
coef = objective_data["coef"]
objectives.push(Objective.new(id, start, target, start_date, end_date, parent_id, coef))
}

input["milestones"].each { |milestone_data| 
objective_id = milestone_data["objective_id"]
objective = objectives.detect { |objective| objective.getId == objective_id}
if objective
    objective.addMilestone(milestone_data)
end
}

objectives.each { |objective| 
parent_id = objective.getParent_id
if parent_id
    parent_objective = objectives.detect { |objective| objective.getId == parent_id}
    parent_objective.addChild(objective)
end
}

objectives.each { |objective|
                id = objective.getId
                progress = input_progress_demands.detect { |progress| progress["objective_id"] == id}
                if progress
                    value = progress["value"]
                    date = Date.parse(progress["date"])
                    output_progress_records.push({"id": progress["id"], "excess": objective.getExcess(value, date, progress["id"])})
                end
            }

output_progress_records.sort! { |a, b| a[:id] <=> b[:id] }

output = {:progress_records => output_progress_records}
output_json = JSON.pretty_generate output

file = File.open("data/output.json", "w"){ |f| f << output_json}
file.close