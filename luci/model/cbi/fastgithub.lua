--[[
FastGitHub LuCI CBI Model v3
Provides configuration UI for FastGitHub Docker container
]]--

require("luci.sys")
require("luci.http")
local fs = require "nixio.fs"
local uci = require "luci.model.uci".cursor()

m = Map("fastgithub", translate("FastGitHub"),
	translate("FastGitHub 是一个 GitHub 加速工具，运行在 Docker 容器中。提供 HTTP/HTTPS 代理加速 GitHub 资源的访问。"))

-- Status section
m:section(SimpleSection).template = "fastgithub/fastgithub_status"

-- Config section
s = m:section(TypedSection, "fastgithub")
s.anonymous = true
s.addremove = false

-- HTTP Proxy Port (editable)
o = s:option(Value, "http_port", translate("HTTP 代理端口"),
	translate("FastGitHub HTTP 代理监听端口，修改后需重启容器生效。"))
o.default = "38457"
o.datatype = "port"
o.optional = false

-- HTTPS Reverse Proxy Port (editable)
o = s:option(Value, "https_port", translate("HTTPS 代理端口"),
	translate("FastGitHub HTTPS 反向代理监听端口，修改后需重启容器生效。"))
o.default = "38443"
o.datatype = "port"
o.optional = false

-- Separator
o = s:option(DummyValue, "_sep1", translate(""))
o.template = "cbi/dvalue"

-- Config file path (read-only display)
o = s:option(DummyValue, "_config_path", translate("配置文件路径"),
	translate("FastGitHub 配置文件在容器内的路径。"))
function o.cfgvalue() return uci:get("fastgithub", "config", "config_path") or "/fastgithub/appsettings.json" end

-- Cert path (read-only display)
o = s:option(DummyValue, "_cert_path", translate("证书文件路径"),
	translate("FastGitHub 证书文件在容器内的目录路径。"))
function o.cfgvalue() return uci:get("fastgithub", "config", "cert_path") or "/fastgithub/cacert" end

-- Binary path (read-only display)
o = s:option(DummyValue, "_binary_path", translate("可执行文件路径"),
	translate("FastGitHub 可执行文件在容器内的路径。"))
function o.cfgvalue() return uci:get("fastgithub", "config", "binary_path") or "/fastgithub/fastgithub" end

-- Log viewer section
s2 = m:section(SimpleSection, translate("运行日志"),
	translate("FastGitHub 容器实时日志输出，每 5 秒自动刷新。"))
s2.template = "fastgithub/fastgithub_log"

-- Handle save
local apply = luci.http.formvalue("cbi.submit")
if apply then
	local http_port = luci.http.formvalue("cbid.fastgithub.config.http_port")
	local https_port = luci.http.formvalue("cbid.fastgithub.config.https_port")

	if http_port and http_port ~= "" then
		uci:set("fastgithub", "config", "http_port", http_port)
	end
	if https_port and https_port ~= "" then
		uci:set("fastgithub", "config", "https_port", https_port)
	end
	uci:commit("fastgithub")

	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "fastgithub"))
	return
end

return m
