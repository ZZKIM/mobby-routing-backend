-- 예시 프로파일: custom.lua

-- 기본 프로파일 로드
require "lib/access"
require "lib/guidance"

local speed_profile = {
  ["primary"] = 25,  -- 기본 속도 설정
  ["primary_link"] = 20,
  ["secondary"] = 20,
  ["secondary_link"] = 15,
  -- 다른 도로 유형에 대한 속도 설정
}

-- CSV 파일에서 특정 구간 정보 읽기
local csv = require "csv"
local avoidance_penalty = 1000
local avoidance_segments = {}

-- CSV 파일 경로
local csv_file = "/path/to/your/avoidance_segments.csv"

-- CSV 파일 읽기
for row in csv.open(csv_file) do
  local segment_name = row[1]
  local segment_start = tonumber(row[2])
  local segment_end = tonumber(row[3])
  avoidance_segments[segment_name] = {start = segment_start, end = segment_end}
end

function way_function (way, result)
  -- way 타입 및 특성을 기준으로 가중치 조정
  local highway = way:get_value_by_key("highway")
  if highway == "tertiary" then
    result.forward_speed = 15 -- tertiary 도로의 속도를 15로 설정
  elseif highway == "residential" then
    result.forward_speed = 20 -- residential 도로의 속도를 20으로 설정
  end

  -- 특정 구간 회피
  for segment_name, segment in pairs(avoidance_segments) do
    if result.way_id >= segment.start and result.way_id <= segment.end then
      result.duration = result.duration + avoidance_penalty
      result.distance = result.distance + avoidance_penalty
      result.avoided = true
      result.segment_name = segment_name
      break
    end
  end
end

-- 프로파일을 등록
return {
  setup = function(profile)
    -- 프로파일 설정
  end,
  way_function = way_function
}
