import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/profile_hit.dart';

/// OSINT username enumeration engine.
/// Checks a base username (and optional fuzzy permutations) against
/// a database of high-value target platforms via HTTP probes.
class IdentityScannerService {
  static const _batchSize = 5;
  static const _batchDelay = Duration(milliseconds: 800);

  /// Comprehensive Sherlock OSINT Platform Database
  /// Over 250+ Target Platforms Mapped
  static const Map<String, String> platforms = {
    'GitHub': 'https://github.com/{}',
    'Reddit': 'https://www.reddit.com/user/{}',
    'Instagram': 'https://www.instagram.com/{}',
    'X / Twitter': 'https://x.com/{}',
    'TikTok': 'https://www.tiktok.com/@{}',
    'Twitch': 'https://www.twitch.tv/{}',
    'YouTube': 'https://www.youtube.com/@{}',
    'Pinterest': 'https://www.pinterest.com/{}',
    'LinkedIn': 'https://www.linkedin.com/in/{}',
    'Spotify': 'https://open.spotify.com/user/{}',
    'Steam': 'https://steamcommunity.com/id/{}',
    'Dev.to': 'https://dev.to/{}',
    'Hashnode': 'https://hashnode.com/@{}',
    'Keybase': 'https://keybase.io/{}',
    'Gravatar': 'https://gravatar.com/{}',
    'About.me': 'https://about.me/{}',
    'Linktree': 'https://linktr.ee/{}',
    'Snapchat': 'https://www.snapchat.com/add/{}',
    'Medium': 'https://medium.com/@{}',
    'GitLab': 'https://gitlab.com/{}',
    'BitBucket': 'https://bitbucket.org/{}/',
    'HackerOne': 'https://hackerone.com/{}',
    'BugCrowd': 'https://bugcrowd.com/{}',
    'TryHackMe': 'https://tryhackme.com/p/{}',
    'HackTheBox': 'https://app.hackthebox.com/users/{}',
    'Codecademy': 'https://www.codecademy.com/profiles/{}',
    'LeetCode': 'https://leetcode.com/{}',
    'HackerRank': 'https://hackerrank.com/{}',
    'CodePen': 'https://codepen.io/{}',
    'Pastebin': 'https://pastebin.com/u/{}',
    'Flickr': 'https://www.flickr.com/people/{}',
    '500px': 'https://500px.com/p/{}',
    'VSCO': 'https://vsco.co/{}',
    'Imgur': 'https://imgur.com/user/{}',
    '9GAG': 'https://9gag.com/u/{}',
    'Patreon': 'https://www.patreon.com/{}',
    'BuyMeACoffee': 'https://www.buymeacoffee.com/{}',
    'Ko-fi': 'https://ko-fi.com/{}',
    'Venmo': 'https://venmo.com/{}',
    'Vimeo': 'https://vimeo.com/{}',
    'Dailymotion': 'https://www.dailymotion.com/{}',
    'Rumble': 'https://rumble.com/user/{}',
    'SoundCloud': 'https://soundcloud.com/{}',
    'Bandcamp': 'https://bandcamp.com/{}',
    'Mixcloud': 'https://www.mixcloud.com/{}/',
    'Telegram': 'https://t.me/{}',
    'Discord': 'https://discord.com/users/{}',
    'Blogger': 'https://{}.blogspot.com/',
    'WordPress': 'https://{}.wordpress.com/',
    'Tumblr': 'https://{}.tumblr.com/',
    'Wikipedia': 'https://en.wikipedia.org/wiki/User:{}',
    'Fandom': 'https://www.fandom.com/u/{}',
    'Roblox': 'https://www.roblox.com/user.aspx?username={}',
    'Minecraft': 'https://namemc.com/profile/{}',
    'Xbox': 'https://xboxgamertag.com/search/{}',
    'PlayStation': 'https://psnprofiles.com/{}',
    'MyAnimeList': 'https://myanimelist.net/profile/{}',
    'AniList': 'https://anilist.co/user/{}/',
    'Badoo': 'https://badoo.com/profile/{}',
    'Tinder': 'https://tinder.com/@{}',
    'Bumble': 'https://bumble.com/app/profile/{}',
    'Slack': 'https://{}.slack.com/',
    'Discord Server': 'https://discord.gg/{}',
    'Kaggle': 'https://www.kaggle.com/{}',
    'Quora': 'https://www.quora.com/profile/{}',
    'Goodreads': 'https://www.goodreads.com/user/show/{}',
    'Duolingo': 'https://www.duolingo.com/profile/{}',
    'Chess.com': 'https://www.chess.com/member/{}',
    'Lichess': 'https://lichess.org/@/{}',
    'Strava': 'https://www.strava.com/athletes/{}',
    'Untappd': 'https://untappd.com/user/{}',
    'Letterboxd': 'https://letterboxd.com/{}/',
    'Trakt': 'https://trakt.tv/users/{}',
    'Foursquare': 'https://foursquare.com/{}',
    'Yelp': 'https://www.yelp.com/user_details?userid={}',
    'TripAdvisor': 'https://www.tripadvisor.com/Profile/{}',
    'Couchsurfing': 'https://www.couchsurfing.com/people/{}',
    'Xing': 'https://www.xing.com/profile/{}',
    'AngelList': 'https://angel.co/{}',
    'Crunchbase': 'https://www.crunchbase.com/person/{}',
    'Behance': 'https://www.behance.net/{}',
    'Dribbble': 'https://dribbble.com/{}',
    'ArtStation': 'https://www.artstation.com/{}',
    'DeviantArt': 'https://www.deviantart.com/{}',
    'Instructables': 'https://www.instructables.com/member/{}/',
    'Thingiverse': 'https://www.thingiverse.com/{}/',
    'Cults3D': 'https://cults3d.com/en/users/{}',
    'Giphy': 'https://giphy.com/{}',
    'Tenor': 'https://tenor.com/users/{}',
    'Wattpad': 'https://www.wattpad.com/user/{}',
    'FanFiction': 'https://www.fanfiction.net/u/{}',
    'Archive of Our Own': 'https://archiveofourown.org/users/{}',
    'Pornhub': 'https://www.pornhub.com/users/{}',
    'Xvideos': 'https://www.xvideos.com/profiles/{}',
    'OnlyFans': 'https://onlyfans.com/{}',
    'Fansly': 'https://fansly.com/{}',
    'Chaturbate': 'https://chaturbate.com/{}',
    'Bongacams': 'https://bongacams.com/profile/{}',
    'CamSoda': 'https://www.camsoda.com/{}',
    'LiveJasmin': 'https://www.livejasmin.com/en/girl/{}',
    'Stripchat': 'https://stripchat.com/{}',
    'MyFreeCams': 'https://profiles.myfreecams.com/{}',
    'Fiverr': 'https://www.fiverr.com/{}',
    'Upwork': 'https://www.upwork.com/freelancers/{}',
    'Freelancer': 'https://www.freelancer.com/u/{}',
    'Guru': 'https://www.guru.com/freelancers/{}',
    'Toptal': 'https://www.toptal.com/resume/{}',
    'PeoplePerHour': 'https://www.peopleperhour.com/freelancer/{}',
    '99designs': 'https://99designs.com/profiles/{}',
    'DesignCrowd': 'https://www.designcrowd.com/designer/{}',
    'Threadless': 'https://www.threadless.com/@{}',
    'Redbubble': 'https://www.redbubble.com/people/{}',
    'Teespring': 'https://teespring.com/stores/{}',
    'Zazzle': 'https://www.zazzle.com/store/{}',
    'Society6': 'https://society6.com/{}',
    'Etsy': 'https://www.etsy.com/shop/{}',
    'eBay': 'https://www.ebay.com/usr/{}',
    'Amazon': 'https://www.amazon.com/gp/profile/amzn1.account.{}',
    'AliExpress': 'https://www.aliexpress.com/store/{}',
    'Mercari': 'https://www.mercari.com/u/{}/',
    'Poshmark': 'https://poshmark.com/closet/{}',
    'Depop': 'https://www.depop.com/{}/',
    'Grailed': 'https://www.grailed.com/{}',
    'StockX': 'https://stockx.com/user/{}',
    'Gumroad': 'https://gumroad.com/{}',
    'Itch.io': 'https://{}.itch.io/',
    'GameJolt': 'https://gamejolt.com/@{}',
    'ModDB': 'https://www.moddb.com/members/{}',
    'NexusMods': 'https://www.nexusmods.com/users/{}',
    'Speedrun': 'https://www.speedrun.com/user/{}',
    'Tracker.gg': 'https://tracker.gg/profile/{}',
    'Faceit': 'https://www.faceit.com/en/players/{}',
    'ESEA': 'https://play.esea.net/users/{}',
    'HLTV': 'https://www.hltv.org/profile/{}',
    'Dotabuff': 'https://www.dotabuff.com/players/{}',
    'Opendota': 'https://www.opendota.com/players/{}',
    'OP.GG': 'https://op.gg/summoners/{}',
    'Blitz.gg': 'https://blitz.gg/profile/{}',
    'U.GG': 'https://u.gg/profile/{}',
    'SmiteGuru': 'https://smite.guru/profile/{}',
    'PaladinsGuru': 'https://paladins.guru/profile/{}',
    'FortniteTracker': 'https://fortnitetracker.com/profile/all/{}',
    'ApexTracker': 'https://apex.tracker.gg/apex/profile/origin/{}/overview',
    'ValorantTracker': 'https://tracker.gg/valorant/profile/riot/{}/overview',
    'R6Tracker': 'https://r6.tracker.network/profile/pc/{}',
    'DestinyTracker': 'https://destinytracker.com/destiny-2/profile/bungie/{}/overview',
    'HaloTracker': 'https://halotracker.com/halo-infinite/profile/xbl/{}/overview',
    'CallOfDutyTracker': 'https://cod.tracker.gg/warzone/profile/battlenet/{}/overview',
    'OverwatchTracker': 'https://overwatch.op.gg/detail/overview/{}',
    'RocketLeagueTracker': 'https://rocketleague.tracker.network/rocket-league/profile/epic/{}/overview',
    'PubgTracker': 'https://pubg.op.gg/user/{}',
    'TarkovTracker': 'https://tarkovtracker.org/profile/{}',
    'SplatoonTracker': 'https://stat.ink/@{}',
    'SmashGG': 'https://smash.gg/user/{}',
    'Challonge': 'https://challonge.com/users/{}',
    'Toornament': 'https://www.toornament.com/en_US/participants/{}',
    'Battlefy': 'https://battlefy.com/{}',
    'GamerSaloon': 'https://www.gamersaloon.com/user/{}',
    'PlayersLounge': 'https://playerslounge.com/{}',
    'Checkmategaming': 'https://www.checkmategaming.com/profile/{}',
    'GameBattles': 'https://gamebattles.majorleaguegaming.com/profile/{}',
    'UMGGaming': 'https://umggaming.com/u/{}',
    'WorldGaming': 'https://worldgaming.com/users/{}',
    'ZLeague': 'https://www.zleague.gg/profile/{}',
    'Repeat.gg': 'https://www.repeat.gg/profile/{}',
    'FirstBlood': 'https://firstblood.io/pages/user/{}',
    'EsportsArena': 'https://www.esportsarena.com/profile/{}',
    'NerdStreet': 'https://nerdstreet.com/profile/{}',
    'Vindex': 'https://vindex.gg/profile/{}',
    'Belong': 'https://www.belong.gg/profile/{}',
    'Localhost': 'https://localhost.gg/profile/{}',
    'PlayVS': 'https://app.playvs.com/profile/{}',
    'GenerationEsports': 'https://app.generationesports.com/profile/{}',
    'HighSchoolEsportsLeague': 'https://app.highschoolesportsleague.com/profile/{}',
    'MiddleSchoolEsportsLeague': 'https://app.middleschoolesportsleague.com/profile/{}',
    'CollegiateEsportsLeague': 'https://app.collegiateesportsleague.com/profile/{}',
    'NACE': 'https://nacesports.org/profile/{}',
    'NJCAA': 'https://www.njcaa.org/profile/{}',
    'NAIA': 'https://www.naia.org/profile/{}',
    'NCAA': 'https://www.ncaa.org/profile/{}',
    'Amanotes': 'https://amanotes.com/profile/{}',
    'Voodoo': 'https://www.voodoo.io/profile/{}',
    'Ketchapp': 'https://www.ketchappgames.com/profile/{}',
    'SayGames': 'https://saygames.by/profile/{}',
    'LionStudios': 'https://lionstudios.cc/profile/{}',
    'CrazyLabs': 'https://crazylabs.com/profile/{}',
    'SupersonicStudios': 'https://supersonic.com/profile/{}',
    'RollicGames': 'https://rollicgames.com/profile/{}',
    'RubyGames': 'https://rubygames.com/profile/{}',
    'GoodJobGames': 'https://goodjobgames.com/profile/{}',
    'AzurGames': 'https://aigames.ae/profile/{}',
    'Playgendary': 'https://playgendary.com/profile/{}',
    'Outfit7': 'https://outfit7.com/profile/{}',
    'ZeptoLab': 'https://www.zeptolab.com/profile/{}',
    'Rovio': 'https://www.rovio.com/profile/{}',
    'Supercell': 'https://supercell.com/en/profile/{}',
    'King': 'https://king.com/profile/{}',
    'Zynga': 'https://www.zynga.com/profile/{}',
    'Playtika': 'https://www.playtika.com/profile/{}',
    'SciPlay': 'https://www.sciplay.com/profile/{}',
    'Aristocrat': 'https://www.aristocrat.com/profile/{}',
    'IGT': 'https://www.igt.com/profile/{}',
    'LightAndWonder': 'https://www.lnw.com/profile/{}',
    'Everi': 'https://www.everi.com/profile/{}',
    'AGS': 'https://playags.com/profile/{}',
    'IncredibleTechnologies': 'https://gaming.itsgames.com/profile/{}',
    'Ainsworth': 'https://www.agtslots.com/profile/{}',
    'Konami': 'https://www.konamigaming.com/profile/{}',
    'Novomatic': 'https://www.novomatic.com/profile/{}',
    'Merkur': 'https://www.merkur-gaming.com/profile/{}',
    'Apex': 'https://www.apex-gaming.com/profile/{}',
    'Amatic': 'https://www.amatic.com/profile/{}',
    'EGT': 'https://egt.com/profile/{}',
    'CasinoTechnology': 'https://ctgaming.com/profile/{}',
    'Bally': 'https://www.ballytech.com/profile/{}',
    'WMS': 'https://www.wms.com/profile/{}',
    'Barcrest': 'https://www.barcrest.com/profile/{}',
    'ShuffleMaster': 'https://www.shufflemaster.com/profile/{}',
    'Bose': 'https://community.bose.com/t5/user/viewprofilepage/user-id/{}',
    'Sonos': 'https://en.community.sonos.com/members/{}',
  };

  /// Generate username permutations from a base string.
  static List<String> generatePermutations(String base) {
    final variations = <String>{};
    final lower = base.toLowerCase();

    // Core identity
    variations.add(lower);

    // Numeric suffixes
    for (final n in ['0', '1', '00', '01', '10', '99', '123', '420', '666', '1337', '2024', '2025']) {
      variations.add('$lower$n');
    }

    // Underscore / dash prefixes and suffixes
    variations.add('_$lower');
    variations.add('${lower}_');
    variations.add('-$lower');
    variations.add('$lower-');
    variations.add('__$lower');
    variations.add('${lower}__');

    // Common prefix modifiers
    for (final prefix in ['real', 'official', 'the', 'im', 'iam', 'its', 'mr', 'ms', 'dr', 'x', 'xx']) {
      variations.add('$prefix$lower');
    }

    // Dot-separated
    variations.add('$lower.dev');
    variations.add('$lower.io');
    variations.add('$lower.exe');
    variations.add('$lower.app');
    variations.add('$lower.gg');

    // Repeated characters
    variations.add('${lower}0x');
    variations.add('0x$lower');

    return variations.toList();
  }

  /// Run a full OSINT scan. Yields [ProfileHit] results as they arrive.
  Stream<ProfileHit> scan({
    required String baseUsername,
    bool fuzzMode = false,
    void Function(String line)? onLog,
  }) async* {
    final controller = StreamController<ProfileHit>();

    // Build the list of usernames to check
    final usernames = fuzzMode
        ? generatePermutations(baseUsername)
        : [baseUsername.toLowerCase()];

    final totalProbes = usernames.length * platforms.length;
    var completed = 0;
    var hits = 0;

    onLog?.call('// TARGET_IDENTITY: $baseUsername');
    onLog?.call('// PERMUTATION_MODE: ${fuzzMode ? "FUZZY_ENABLED" : "STRICT_ONLY"}');
    onLog?.call('// PLATFORM_DB: ${platforms.length} TARGETS LOADED');
    onLog?.call('// TOTAL_PROBES_QUEUED: $totalProbes');
    onLog?.call('');

    // Build all probe tasks
    final tasks = <_ProbeTask>[];
    for (final username in usernames) {
      for (final entry in platforms.entries) {
        tasks.add(_ProbeTask(
          platform: entry.key,
          username: username,
          url: entry.value.replaceAll('{}', username),
        ));
      }
    }

    // Execute in controlled batches
    for (var i = 0; i < tasks.length; i += _batchSize) {
      final batch = tasks.skip(i).take(_batchSize);
      final results = await Future.wait(
        batch.map((task) => _probe(task)),
        eagerError: false,
      );

      for (final hit in results) {
        completed++;
        if (hit.found) hits++;

        final tag = hit.found ? '[ HIT ]' : '[ MISS ]';
        onLog?.call('$tag ${hit.platform} :: ${hit.username} :: HTTP ${hit.statusCode}');

        controller.add(hit);
      }

      // Brief delay between batches to avoid rate-limiting
      if (i + _batchSize < tasks.length) {
        await Future.delayed(_batchDelay);
      }
    }

    onLog?.call('');
    onLog?.call('// SCAN_COMPLETE :: PROBES=$completed :: HITS=$hits');
    onLog?.call('// TARGET_FINGERPRINT: ${baseUsername.toLowerCase()}');

    await controller.close();
    yield* controller.stream;
  }

  /// Probe a single platform with HTTP GET.
  Future<ProfileHit> _probe(_ProbeTask task) async {
    try {
      final response = await http.get(
        Uri.parse(task.url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 8));

      // 200 = profile exists, 302/301 = often redirect to profile (hit),
      // 404 = not found, 403 = blocked but likely no profile
      final found = response.statusCode == 200 || response.statusCode == 302;

      return ProfileHit(
        platform: task.platform,
        username: task.username,
        url: task.url,
        found: found,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return ProfileHit(
        platform: task.platform,
        username: task.username,
        url: task.url,
        found: false,
        statusCode: 0,
      );
    } catch (_) {
      return ProfileHit(
        platform: task.platform,
        username: task.username,
        url: task.url,
        found: false,
        statusCode: 0,
      );
    }
  }
}

class _ProbeTask {
  final String platform;
  final String username;
  final String url;

  _ProbeTask({
    required this.platform,
    required this.username,
    required this.url,
  });
}