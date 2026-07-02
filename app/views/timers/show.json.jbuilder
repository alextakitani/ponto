if @time_entry
  json.partial! "time_entries/time_entry", time_entry: @time_entry
else
  json.null!
end
