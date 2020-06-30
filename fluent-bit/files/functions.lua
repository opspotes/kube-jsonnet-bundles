function dedot(tag, timestamp, record)
  if record["kubernetes"] == nil then
    return 0, 0, 0
  end
  if record["kubernetes"]["annotations"] ~= nil then
    record["kubernetes"]["annotations"] = dedot_keys(record["kubernetes"]["annotations"])
  end
  if record["kubernetes"]["labels"] ~= nil then
    record["kubernetes"]["labels"] = dedot_keys(record["kubernetes"]["labels"])
  end
  return 1, timestamp, record
end

function dedot_keys(map)
  new_map = {}
  for k, v in pairs(map) do
    dedotted = string.gsub(k, "%.", "_")
    if k ~= dedotted then
      new_map[dedotted] = v
    else
      new_map[k] = v
    end
  end
  return new_map
end
