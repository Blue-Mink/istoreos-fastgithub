--[[
FastGitHub LuCI Controller
Provides configuration page and status/control API for FastGitHub Docker container
]]--

module("luci.controller.fastgithub", package.seeall)

function index()
	entry({"admin", "services", "fastgithub"},
		cbi("fastgithub"),
		_("FastGitHub"), 30).dependent = true

	entry({"admin", "services", "fastgithub", "status"},
		call("act_status")).leaf = true

	entry({"admin", "services", "fastgithub", "control"},
		call("act_control")).leaf = true

	entry({"admin", "services", "fastgithub", "log"},
		call("act_log")).leaf = true
end

function act_status()
	local http = require "luci.http"
	local sys  = require "luci.sys"
	local json = {}

	local container = "fastgithub"
	json.running = (sys.call("docker inspect " .. container .. " --format '{{.State.Status}}' 2>/dev/null | grep -q running") == 0)
	json.started_at = ""

	if json.running then
		local handle = io.popen("docker inspect " .. container .. " --format '{{.State.StartedAt}}' 2>/dev/null")
		if handle then
			local started = handle:read("*a")
			handle:close()
			json.started_at = started:match("%S+%s+%S+") or ""
		end
	end

	local uci = require "luci.model.uci".cursor()
	json.enabled = uci:get("fastgithub", "config", "enabled") == "1"
	json.http_port = uci:get("fastgithub", "config", "http_port") or "38457"
	json.https_port = uci:get("fastgithub", "config", "https_port") or "38443"
	json.config_path = uci:get("fastgithub", "config", "config_path") or "/fastgithub/appsettings.json"
	json.cert_path = uci:get("fastgithub", "config", "cert_path") or "/fastgithub/cacert"
	json.binary_path = uci:get("fastgithub", "config", "binary_path") or "/fastgithub/fastgithub"

	local handle = io.popen("docker inspect " .. container .. " --format '{{.Config.Image}}' 2>/dev/null")
	if handle then
		json.image = handle:read("*a"):gsub("%s+$", "")
		handle:close()
	else
		json.image = ""
	end

	http.prepare_content("application/json")
	http.write_json(json)
end

function act_control()
	local http = require "luci.http"
	local sys  = require "luci.sys"
	local action = http.formvalue("action")
	local container = "fastgithub"

	if action == "start" then
		sys.call("docker start " .. container .. " 2>/dev/null")
	elseif action == "stop" then
		sys.call("docker stop " .. container .. " 2>/dev/null")
	elseif action == "restart" then
		sys.call("docker restart " .. container .. " 2>/dev/null")
	end

	http.prepare_content("application/json")
	http.write_json({ok = true, action = action})
end

function act_log()
	local http = require "luci.http"
	local json = {}
	local tail_lines = 100
	local container = "fastgithub"

	local handle = io.popen("docker logs " .. container .. " --tail " .. tail_lines .. " 2>&1")
	if handle then
		local log = handle:read("*a")
		handle:close()
		json.log = log
		json.tail = tail_lines
	else
		json.log = "(无法获取日志)"
		json.tail = 0
	end

	http.prepare_content("application/json")
	http.write_json(json)
end
