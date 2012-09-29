module vibenews.web;

import vibenews.db;

import vibe.core.log;
import vibe.crypto.passwordhash;
import vibe.data.bson;
import vibe.http.router;
import vibe.http.server;
import vibe.http.fileserver;
import vibe.inet.rfc5322;
import vibe.utils.string;

import std.conv;
import std.datetime;
import std.exception;


class WebInterface {
	private {
		Controller m_ctrl;
		string m_title = "My Forum";
	}

	this(Controller ctrl)
	{
		m_ctrl = ctrl;

		auto settings = new HttpServerSettings;
		settings.port = 8009;
		settings.bindAddresses = ["127.0.0.1"];

		auto router = new UrlRouter;
		router.get("/", &showIndex);
		router.get("/groups/:group/", &showGroup);
		router.get("/groups/:group/:thread/", &showThread);
		router.get("/groups/:group/:thread/reply", &showReply);
		router.post("/groups/:group/:thread/reply", &postReply);
		router.get("*", serveStaticFiles("public"));

		listenHttp(settings, router);
	}

	void showIndex(HttpServerRequest req, HttpServerResponse res)
	{
		static struct Info1 {
			string title;
			Category[] groupCategories;
		}
		Info1 info;
		info.title = m_title;

		Category cat;
		cat.title = "All";
		m_ctrl.enumerateGroups((idx, grp){ cat.groups ~= GroupInfo(grp, m_ctrl); });
		info.groupCategories ~= cat;

		res.renderCompat!("vibenews.web.index.dt",
			HttpServerRequest, "req",
			Info1*, "info")(Variant(req), Variant(&info));
	}

	void showGroup(HttpServerRequest req, HttpServerResponse res)
	{
		static struct Info2 {
			string title;
			GroupInfo group;
			ThreadInfo[] threads;
			size_t start = 0;
			size_t pageSize = 10;
			size_t pageCount;
		}
		Info2 info;
		info.title = m_title;
		if( auto ps = "start" in req.query ) info.start = to!size_t(*ps);

		auto grp = m_ctrl.getGroupByName(req.params["group"]);
		info.group = GroupInfo(grp, m_ctrl);
		m_ctrl.enumerateThreads(grp._id, info.start, info.pageSize, (idx, thr){
			ThreadInfo thrinfo;
			thrinfo.id = thr._id;
			thrinfo.subject = thr.subject;
			thrinfo.postCount = cast(size_t)m_ctrl.getThreadPostCount(thr._id, grp.name);
			thrinfo.pageCount = (thrinfo.postCount + info.pageSize-1) / info.pageSize;
			thrinfo.pageSize = info.pageSize;

			try {
				auto firstpost = m_ctrl.getArticle(thr.firstArticleId);
				thrinfo.firstPoster = PosterInfo(firstpost.getHeader("From"));
				thrinfo.firstPostDate = firstpost.getHeader("Date");//.parseRFC822DateTimeString();
				auto lastpost = m_ctrl.getArticle(thr.lastArticleId);
				thrinfo.lastPoster = PosterInfo(lastpost.getHeader("From"));
				thrinfo.lastPostDate = lastpost.getHeader("Date");//.parseRFC822DateTimeString();
			} catch( Exception ){}

			info.threads ~= thrinfo;
		});
		
		info.pageCount = (info.group.numberOfTopics + info.pageSize-1) / info.pageSize;

		res.renderCompat!("vibenews.web.view_group.dt",
			HttpServerRequest, "req",
			Info2*, "info")(Variant(req), Variant(&info));
	}

	void showThread(HttpServerRequest req, HttpServerResponse res)
	{
		static struct Info3 {
			string title;
			GroupInfo group;
			PostInfo[] posts;
		}
		Info3 info;

		auto threadid = BsonObjectID.fromString(req.params["thread"]);
		auto grp = m_ctrl.getGroupByName(req.params["group"]);
		info.group = GroupInfo(grp, m_ctrl);

		m_ctrl.enumerateThreadPosts(threadid, grp.name, 0, 10, (idx, art){
			info.posts ~= PostInfo(art, art);
		});

		res.renderCompat!("vibenews.web.view_thread.dt",
			HttpServerRequest, "req",
			Info3*, "info")(Variant(req), Variant(&info));
	}

	void showReply(HttpServerRequest req, HttpServerResponse res)
	{
		static struct Info4 {
			string title;
			GroupInfo group;
		}
		Info4 info;

		auto threadid = BsonObjectID.fromString(req.params["thread"]);
		auto grp = m_ctrl.getGroupByName(req.params["group"]);
		info.group = GroupInfo(grp, m_ctrl);

		res.renderCompat!("vibenews.web.reply.dt",
			HttpServerRequest, "req",
			Info4*, "info")(Variant(req), Variant(&info));
	}

	void postReply(HttpServerRequest req, HttpServerResponse res)
	{
		auto groupname = req.params["group"];
		auto threadid = req.params["thread"];

		res.redirect(formatString("/%s/%s/", groupname, threadid));
	}
}

struct GroupInfo {
	this(Group grp, Controller ctrl)
	{
		try {
			auto lastpost = ctrl.getArticle(grp.name, grp.maxArticleNumber);
			lastPoster = PosterInfo(lastpost.getHeader("From"));
			lastPostDate = lastpost.getHeader("Date");//.parseRFC822DateTimeString();
		} catch( Exception ){}

		name = grp.name;
		description = grp.description;
		numberOfPosts = cast(size_t)grp.articleCount;
		numberOfTopics = cast(size_t)ctrl.getThreadCount(grp._id);
	}

	string name;
	string description;
	size_t numberOfTopics;
	size_t numberOfPosts;
	PosterInfo lastPoster;
	//SysTime lastPostDate;
	string lastPostDate;
}

struct ThreadInfo {
	BsonObjectID id;
	string subject;
	PosterInfo firstPoster;
	//SysTime firstPostDate;
	string firstPostDate;
	PosterInfo lastPoster;
	//SysTime lastPostDate;
	string lastPostDate;
	size_t pageSize;
	size_t pageCount;
	size_t postCount;
}

struct PostInfo {
	this(Article art, Article repl_art)
	{
		id = art._id;
		subject = art.getHeader("Subject");
		poster = PosterInfo(art.getHeader("From"));
		repliedToPoster = PosterInfo(repl_art.getHeader("From"));
		date = art.getHeader("Date");
		message = sanitizeUTF8(art.message);
	}

	BsonObjectID id;
	string subject;
	PosterInfo poster;
	PosterInfo repliedToPoster;
	//SysTime date;
	string date;
	string message;
}

struct PosterInfo {
	this(string str)
	{
		name = str;
	}

	string name;
	string email;
}

struct Category {
	string title;
	GroupInfo[] groups;
}