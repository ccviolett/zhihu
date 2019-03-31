#!/usr/bin/lua
require("lfs")
require("socket")
local https = require("ssl.https")

item = { name="", link="", id="", kind="", path="", source="" };
configPath = os.getenv("HOME") .. "/.config/zhihu/";
savePath = "./";
pageSource = "";

-- Function
get_source = "";
check_path = "";
convert_image = "";
analysis = "";
analysis_qustion = "";
analysis_zhuanlan = "";
assemble = "";
add = "";
init = "";
query = "";

function check_path(path)
	return os.rename(path, path) and true or false;
end

get_source = function(link) 
	-- os.execute("curl " .. link .. " -o " .. id .. "/index.html -s");
	local body, code, headers, status = https.request(link);
	return body;
end

function convert_image(item)
	local tot = 0;
	local list = {};
	for link in string.gmatch(item["source"], "original=\"([^\"]+)\"") do 
		list[#list + 1] = link;
	end
	for i, v in ipairs(list) do
		print("Downloading(" .. i .. "/" .. #list .. "): " .. v);
		os.execute("curl " .. v .. " -o " .. item["path"] .. "image_" .. i .. ".jpg -s");
	end
	-- TODO
	-- 美化此处代码
	cnt = 1;
	for img in string.gmatch(item["source"], "<img src=\"https://[^>]+>") do
		item["source"] = string.gsub(item["source"], img, "<img src=\"./image_" .. cnt .. ".jpg\" class=\"origin_image zh-lightbox-thumb lazy\"");
		cnt = cnt + 1;
	end
	return item["source"];
end

function analysis(item)
	if item["kind"] == "answer" then 
		item["source"] = analysis_qustion(item["source"]);
	elseif item["kind"] == "zhuanlan" then
		item["source"] = analysis_zhuanlan(item["source"]);
	end
    item["source"] = string.gsub(item["source"], "href=\"//www.zhihu.com", "href=\"https://www.zhihu.com");
	return convert_image(item);
end

function analysis_zhuanlan(source)
    source = string.match(source, "(<article.-</article>)");
	source = string.gsub(source, "<noscript>", "");
	source = string.gsub(source, "</noscript>", "");
    source = string.gsub(source, "<div class=\"Post%-topicsAndReviewer\">.+</div>", "");
	source = string.gsub(source, "<img src=\"data:image/[^>]+>", "");
    return source;
end

analysis_qustion = function(source) 
	source = string.match(source, "(<div class=\"RichContent%-inner\">.+)</span></div>");
	source = string.gsub(source, "<noscript>", "");
	source = string.gsub(source, "</noscript>", "");
	source = string.gsub(source, "<img src=\"data:image/[^>]+>", "");
	return source;
end

function assemble(source)
	local header = io.open(configPath .. "lib/header.html", "r"):read("*a");
    local css = "\
        <link rel=\"stylesheet\" type=\"text/css\" href=\"" .. configPath .. "lib/css/column.app.703601291595f60c1a4c.css\">\
        <link rel=\"stylesheet\" type=\"text/css\" href=\"" .. configPath .. "lib/css/common.css\">\
";
    local body = io.open(configPath .. "lib/body.html", "r"):read("*a");
	local footer = io.open(configPath .. "lib/footer.html", "r"):read("*a");
	local res = header .. css .. body .. source .. footer;
	return res;
end

function add(infor)
	item["link"] = string.match(infor, "(https://.+)");
	item["source"] = get_source(item["link"]);
    item["name"] = string.match(item["source"], "<title.->(.-)</title>");
	-- item["name"] = string.match(string.match(infor, "(.-)\n"), "(.+) %-");
	if string.match(item["link"], "answer") then 
		item["id"] = string.match(infor, "/answer/(.+)");
		item["kind"] = "answer";
		item["path"] = savePath .. "answer/" .. item["id"] .. "/";
		print("==== Add [Question] " .. item["name"] .. " ====");
	elseif string.match(item["link"], "zhuanlan") then
		item["id"] = string.match(infor, "/p/(.+)");
		item["kind"] = "zhuanlan";
		item["path"] = savePath .. "zhuanlan/" .. item["id"] .. "/";
		print("==== Add [Zhuanlan] " .. item["name"] .. " ====");
	else
		print("Illegal link!");
		os.exit(1);
	end
	lfs.mkdir(item["path"]);
	item["source"] = assemble(analysis(item));
	io.open(item["path"] .. "index.html", "w"):write(item["source"]);
	io.open("log", "a"):write(item["name"] .. " " .. item["path"] .. "\n" .. item["link"] .. "\n");
	print("========== Done ==========");
	os.execute("google-chrome-unstable " .. item["path"] .. "index.html");
	return 0;
end

function main() 
	init()
	if arg[1] == nil then
		query();
    else
		add(arg[1]);
	end
end

function init() 
    lfs.mkdir(configPath);
	lfs.mkdir(savePath .. "answer");
	lfs.mkdir(savePath .. "zhuanlan");
end

main();
