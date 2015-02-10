_ = require "lodash"
fs = require "fs-extra"
path = require "path"
urlUtils = require "../utils/url"

module.exports = (request, response, next) ->
	[hostname, ext] = _.values request.params
	cleanHostname = urlUtils.cleanHostname(hostname)

	if cleanHostname != hostname
		response.header 'Location', request.url.replace(hostname, cleanHostname)
		response.send 302
		return next(false)

	filename = path.resolve path.join(global.dex_cache_dir, request.url)

	# Prevent traversal
	if !~filename.indexOf(global.dex_cache_dir)
		next new Error("URL is invalid (#{filename}, #{global.dex_cache_dir})")
		return

	if !fs.existsSync filename
		request.url = "/_default.#{ext}"

	next()