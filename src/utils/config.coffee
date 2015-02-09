_ = require "lodash"
fs = require "fs-extra"
path = require "path"
yaml = require "js-yaml"
glob = require("glob")
pkg = require "../../package.json"
marked = require "marked"

markedOptions =
	renderer: do (r = new marked.Renderer) ->
		# prevent marked from wrapping rendered text in tags
		r.paragraph = r.heading = (p) -> p
		r

globtions = {
	cwd: global.dex_file_dir
	# debug: true
}

_dirsOnly = (d) ->
	return false if d.charAt(0) == "."
	return false unless fs.statSync(d).isDirectory()
	return true

getDexVersionString = ->
	"#{pkg.name} #{pkg.version}"

getDateString = ->
	now = new Date

	[
		["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][now.getDay()]
		" "
		[
			"Jan", "Feb", "Mar", "Apr", "May", "Jun",
			"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
		][now.getMonth()]
		" "
		_.padLeft(now.getDate(), 2, " ")
		" "
		_.padLeft(now.getHours(), 2, "0")
		":"
		_.padLeft(now.getMinutes(), 2, "0")
		":"
		_.padLeft(now.getSeconds(), 2, "0")
		" "
		now.getFullYear()
	].join("")

getConfigFileHeader = ->
	[
		"# Generated by #{getDexVersionString()}"
		"# #{getDateString()}"
		"---"
	].join("\n")

getConfig = ->
	fs.ensureFileSync global.dex_yaml_config_file

	try
		userConfig = yaml.safeLoad fs.readFileSync(
			global.dex_yaml_config_file,
			encoding: "utf8"
		)
		console.info "Loaded #{global.dex_yaml_config_file}".bold
		console.info "#{Object.keys(userConfig).length} sites configured.\n"
	catch e
		console.error "YAML load error! #{e}"
		return {}

	unless typeof userConfig == "object"
		next new Error [
			"Config file is not returning an object when parsed."
			"You might want to check that out: #{global.dex_yaml_config_file}"
		].join(" ")
		return {}

	availableModulesByHostname = {global: []}
	enabledModulesByHostname = {global: []}
	invalidModulesByHostname = {global: []}
	metadataByModuleName = {}
	availableUtilities = []

	buildModuleListForHostname = (hostname) ->
		modulePaths = {}

		try
			process.chdir path.join(global.dex_file_dir, hostname)

			modulePaths = fs.readdirSync(".").filter(_dirsOnly).map (module) ->
				metadata = {}
				modulePath = path.join(hostname, module)
				infoYaml = path.join(global.dex_file_dir, modulePath, "info.yaml")

				try
					metadata = yaml.safeLoad fs.readFileSync(infoYaml, "utf8")
				catch e
					console.error "YAML load error (#{modulePath}/info.yaml): #{e}"
					metadata = {}

				metadata = _.extend {
					Author: null
					Description: null
					URL: null
				}, metadata, {
					Category: hostname
					Title: module
				}

				if typeof metadata["Description"] == "string"
					metadata["Description"] = marked(metadata["Description"], markedOptions)

				metadataByModuleName[modulePath] = metadata

				modulePath

		catch e
			console.log "buildModuleListForHostname error: #{e}"
			modulePaths = {}

		process.chdir global.dex_file_dir

		return modulePaths

	# Set some initial data
	availableModulesByHostname["global"] = buildModuleListForHostname("global")
	availableUtilities = buildModuleListForHostname("utilities")

	process.chdir global.dex_file_dir

	validModules = [].concat fs.readdirSync(".").filter(_dirsOnly).map (hostname) ->
		return [] unless /([^\/]+\.[^\/]+)/.test hostname

		modules = buildModuleListForHostname(hostname)

		availableModulesByHostname[hostname] = [].concat(
			availableUtilities
			modules
		)

		modules

	hostnames = _.union(
		Object.keys(userConfig)
		Object.keys(availableModulesByHostname)
	)

	# Clean nonexistent modules
	hostnames.forEach (hostname) ->
		configModules = userConfig[hostname] || []
		if hostname == "global"
			siteModules = availableModulesByHostname["global"]
		else
			siteModules = [].concat(
				availableModulesByHostname["global"]
				(availableModulesByHostname[hostname] || availableUtilities)
			)

		enabledForHost = _.intersection(siteModules, configModules)
		invalidForHost = _.xor(enabledForHost, configModules)

		if enabledForHost.length > 0
			enabledModulesByHostname[hostname] = enabledForHost

		if invalidForHost.length > 0
			invalidModulesByHostname[hostname] = invalidForHost

		return

	# Here's the biz
	metadata: metadataByModuleName

	modulesByHostname:
		available: availableModulesByHostname
		enabled:   enabledModulesByHostname
		invalid:   invalidModulesByHostname
		utilities: availableUtilities

module.exports.globtions = globtions
module.exports.getConfig = getConfig
module.exports.getConfigFileHeader = getConfigFileHeader
module.exports.getDateString = getDateString
module.exports.getDexVersionString = getDexVersionString