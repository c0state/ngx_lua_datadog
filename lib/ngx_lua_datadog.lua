local ngx_socket_udp = ngx.socket.udp
local table_concat = table.concat
local setmetatable = setmetatable

local statsd_mt = {}
statsd_mt.__index = statsd_mt

function statsd_mt:new(conf)
  local sock = ngx_socket_udp()
  sock:settimeout(conf.timeout)
  local _, err = sock:setpeername(conf.host, conf.port)
  if err then
    return nil, "failed to connect to "..conf.host..":"..tostring(conf.port)..": "..err
  end
  
  local statsd = {
    host = conf.host,
    port = conf.port,
    socket = sock,
    namespace = conf.namespace
  }
  return setmetatable(statsd, statsd_mt)
end

function statsd_mt:create_statsd_message(stat, delta, kind, sample_rate, tags)
  local rate = ""
  if sample_rate and sample_rate ~= 1 then 
    rate = "|@"..sample_rate 
  end
  
  local tag_string = ""
  if tags then
    tag_string = "|#"..tags
  end

  local message = {
    self.namespace,
    ".",
    stat,
    ":",
    delta,
    "|",
    kind,
    rate,
    tag_string
  }
  return table_concat(message, "")
end

function statsd_mt:close_socket()
  local ok, err = self.socket:close()
  if not ok then
    ngx.log(ngx.ERR, "failed to close connection from "..self.host..":"..tostring(self.port)..": ", err)
    return
  end
end

function statsd_mt:send_statsd(stat, delta, kind, sample_rate, tags)
  local udp_message = self:create_statsd_message(stat, delta, kind, sample_rate, tags)
  local ok, err = self.socket:send(udp_message)
  if not ok then
    ngx.log(ngx.ERR, "failed to send data to "..self.host..":"..tostring(self.port)..": ", err)
  end
end

function statsd_mt:gauge(stat, value, sample_rate, tags)
  return self:send_statsd(stat, value, "g", sample_rate, tags)
end

function statsd_mt:counter(stat, value, sample_rate, tags)
  return self:send_statsd(stat, value, "c", sample_rate, tags)
end

function statsd_mt:timer(stat, ms, tags)
  return self:send_statsd(stat, ms, "ms", nil, tags)
end

function statsd_mt:histogram(stat, value, tags)
  return self:send_statsd(stat, value, "h", nil, tags)
end

function statsd_mt:meter(stat, value, tags)
  return self:send_statsd(stat, value, "m", nil, tags)
end

function statsd_mt:set(stat, value, tags)
  return self:send_statsd(stat, value, "s", nil, tags)
end

return statsd_mt

