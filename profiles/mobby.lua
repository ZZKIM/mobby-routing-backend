-- wheelchair_profile.lua

api_version = 4

Set = require('lib/set')
Sequence = require('lib/sequence')
Handlers = require("lib/way_handlers")
find_access_tag = require("lib/access").find_access_tag
Measure = require("lib/measure")

function setup()
  local wheelchair_speed = 6 -- 휠체어 이동 속도 (평균적인 보행 속도로 가정)
  return {
    properties = {
      weight_name                   = 'duration',
      max_speed_for_map_matching    = 60/3.6, -- kmph -> m/s
      call_tagless_node_function    = false,
      traffic_light_penalty         = 2,
      u_turn_penalty                = 2,
      continue_straight_at_waypoint = false,
      use_turn_restrictions         = false,
    },

    default_mode            = mode.wheelchair,
    default_speed           = wheelchair_speed,
    oneway_handling         = 'specific',     -- 'oneway:foot'은 존중하지만 'oneway'는 존중하지 않음

    barrier_blacklist = Set {
      'yes',
      'wall',
      'fence',
      'bollard',  -- 보행자 도로에서는 일반적으로 제한이 없지만, 휠체어는 일부 보행자 전용 도로에 접근할 수 없음
    },

    access_tag_whitelist = Set {
      'yes',
      'foot',
      'permissive',
      'designated',
      'wheelchair' -- 휠체어에 대한 특별한 접근 허용
    },

    access_tag_blacklist = Set {
      'no',
      'agricultural',
      'forestry',
      'private',
      'delivery',
    },

    restricted_access_tag_list = Set {},

    restricted_highway_whitelist = Set {},

    construction_whitelist = Set {},

    access_tags_hierarchy = Sequence {
      'wheelchair',
      'foot',
      'access'
    },

    service_access_tag_blacklist = Set {},

    restrictions = Sequence {
      'wheelchair',
      'foot'
    },

    suffix_list = Set {
      'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'North', 'South', 'West', 'East'
    },

    avoid = Set {
      'impassable',
      'proposed'
    },
    -- 패널티를 주기 위해 추가함 (from bicycle)
    service_penalties = {
        alley = 0.5,
    },

    speeds = Sequence {
      highway = {
        primary         = wheelchair_speed,
        primary_link    = wheelchair_speed,
        secondary       = wheelchair_speed,
        secondary_link  = wheelchair_speed,
        tertiary        = wheelchair_speed,
        tertiary_link   = wheelchair_speed,
        unclassified    = wheelchair_speed,
        residential     = wheelchair_speed,
        road            = wheelchair_speed,
        living_street   = wheelchair_speed,
        service         = wheelchair_speed,
        track           = wheelchair_speed,
        path            = wheelchair_speed,
        steps           = wheelchair_speed,
        pedestrian      = wheelchair_speed,
        footway         = wheelchair_speed,
        pier            = wheelchair_speed,
      },
      slope_speeds = {
        ["steep"] = wheelchair_speed * 0.5,  -- 경사가 가파를 경우 더 낮은 속도 설정
        ["moderate"] = wheelchair_speed * 0.75,  -- 중간 정도의 경사일 경우 보통의 속도 설정
        ["gentle"] = wheelchair_speed,  -- 낮은 경사는 보통 속도 설정
        -- 다른 경사 등급에 대한 설정은 여기에 추가합니다.
      }
      railway = {
        platform        = wheelchair_speed
      },

      amenity = {
        parking         = wheelchair_speed,
        parking_entrance= wheelchair_speed
      },

      man_made = {
        pier            = wheelchair_speed
      },

      leisure = {
        track           = wheelchair_speed
      }
    },

    route_speeds = {
      ferry = 5
    },

    bridge_speeds = {
    },

    surface_speeds = {
      fine_gravel =   wheelchair_speed * 0.75,
      gravel =        wheelchair_speed * 0.75,
      pebblestone =   wheelchair_speed * 0.75,
      mud =           wheelchair_speed * 0.5,
      sand =          wheelchair_speed * 0.5
    },

    tracktype_speeds = {
    },

    smoothness_speeds = {
    }
  }
end

function process_node(profile, node, result)
  local access = find_access_tag(node, profile.access_tags_hierarchy)
  if access then
    if profile.access_tag_blacklist[access] then
      result.barrier = true
    end
  else
    local barrier = node:get_value_by_key("barrier")
    if barrier then
        --  make an exception for rising bollard barriers
        local bollard = node:get_value_by_key("bollard")
        local rising_bollard = bollard and "rising" == bollard

        if profile.barrier_blacklist[barrier] and not rising_bollard then
        result.barrier = true
        end
    end
  end

  local tag = node:get_value_by_key("highway")
  if "traffic_signals" == tag then
    result.traffic_lights = true
  end
end

function process_way(profile, way, result)
  local data = {
    highway = way:get_value_by_key('highway'),
    bridge = way:get_value_by_key('bridge'),
    route = way:get_value_by_key('route'),
    leisure = way:get_value_by_key('leisure'),
    man_made = way:get_value_by_key('man_made'),
    railway = way:get_value_by_key('railway'),
    platform = way:get_value_by_key('platform'),
    amenity = way:get_value_by_key('amenity'),
    public_transport = way:get_value_by_key('public_transport')
  }

  if next(data) == nil then
    return
  end

  local handlers = Sequence {
    WayHandlers.default_mode,
    WayHandlers.blocked_ways,
    WayHandlers.access,
    WayHandlers.oneway,
    WayHandlers.destinations,
    WayHandlers.ferries,
    WayHandlers.movables,
    WayHandlers.speed,
    WayHandlers.surface,
    WayHandlers.classification,
    WayHandlers.roundabouts,
    WayHandlers.startpoint,
    WayHandlers.names,
    WayHandlers.weights
  }

  WayHandlers.run(profile, way, result, data, handlers)
end

function process_turn (profile, turn)
  turn.duration = 0.

  if turn.direction_modifier == direction_modifier.u_turn then
     turn.duration = turn.duration + profile.properties.u_turn_penalty
  end

  if turn.has_traffic_light then
     turn.duration = profile.properties.traffic_light_penalty
  end
  if profile.properties.weight_name == 'routability' then
      if not turn.source_restricted and turn.target_restricted then
          turn.weight = turn.weight + 3000
      end
  end
end

return {
  setup = setup,
  process_way =  process_way,
  process_node = process_node,
  process_turn = process_turn
}
