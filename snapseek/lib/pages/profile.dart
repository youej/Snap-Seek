import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';
import 'package:snapseek/components/listactivityitem.dart';
import 'package:snapseek/pages/edit_profile.dart';
import 'package:snapseek/pages/search.dart';
import 'package:stream_feed_flutter_core/stream_feed_flutter_core.dart' as stream_feed;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String username = "Loading..."; // Initial text
  String profileImageUrl = ""; // URL for profile image, if available
  List<Image> savedImages = []; // List to store fetched images

  int tab = 0;

  final stream_feed.EnrichmentFlags _flags = stream_feed.EnrichmentFlags()
    ..withReactionCounts()
    ..withOwnReactions();
  
  bool _isPaginating = false;

  static const _feedGroup = 'user';

  Future<void> _loadMore() async {
    if (!_isPaginating) {
      _isPaginating = true;
      context.feedBloc
        .loadMoreEnrichedActivities(feedGroup: _feedGroup)
        .whenComplete(() {
          _isPaginating = false;
        });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUsername();
    fetchSavedImages();
  }

  //firebase sign out
  void signUserOut() {
    FirebaseAuth.instance.signOut();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> fetchUsername() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          username = userDoc['username'] as String;
        });
      } else {
        setState(() {
          username = "No username found";
        });
      }
    } else {
      setState(() {
        username = "User not logged in";
      });
    }
  }

  Future<void> fetchSavedImages() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_images')
          .get();

      List<Image> images = snapshot.docs.map((doc) {
        String base64String = doc['base64'];
        return Image.memory(base64Decode(base64String));
      }).toList();

      setState(() {
        savedImages = images;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = context.feedClient;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Profile',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: signUserOut,
              icon: const Icon(Icons.logout),
              color: Colors.black,
            ),
          ]),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                CircleAvatar(
                  radius: 60, // Increased radius for a larger profile image
                  backgroundImage: profileImageUrl.isNotEmpty
                      ? NetworkImage(profileImageUrl)
                      : null,
                  child: profileImageUrl.isEmpty
                      ? const Icon(Icons.person, size: 60)
                      : null,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(username,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProfile(
                                    profileImageUrl: profileImageUrl,
                                    username: username,
                                  ),
                                ),
                              );
                            },
                            child: const Text("Edit",
                                style: TextStyle(fontSize: 16)),
                          ),
                          const Text(" • ",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () {
                              print("Share button tapped");
                            },
                            child: const Text("Share",
                                style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                TextButton(
                  onPressed: () {
                    print("Feed button tapped");
                    tab = 0;
                  },
                  child: const Text("Gallery",
                      style: TextStyle(fontSize: 16, color: Colors.black)),
                ),
                const SizedBox(width: 20), // Spacing between buttons
                TextButton(
                  onPressed: () {
                    print("Gallery button tapped");
                    tab = 1;
                  },
                  child: const Text("Feed",
                      style: TextStyle(fontSize: 16, color: Colors.black)),
                ),
              ],
            ),
          ),
          if (tab == 1)
          stream_feed.FlatFeedCore(
            feedGroup: _feedGroup,
            userId: client.currentUser!.id,
            loadingBuilder: (context) => const Center(
              child: CircularProgressIndicator()
            ),
            emptyBuilder: (context) => const Center(
              child: Text('No activities')
            ),
            errorBuilder: (context, error) => Center(
              child: Text(error.toString()),
            ),
            limit: 10,
            flags: _flags,
            feedBuilder: (
              BuildContext context,
              activities
            ) {
              return RefreshIndicator(
                onRefresh: () {
                  return context.feedBloc.refreshPaginatedEnrichedActivities(
                    feedGroup: _feedGroup,
                    flags: _flags,
                  );
                },
                child: ListView.separated(
                  itemCount: activities.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    bool shouldLoadMore = activities.length - 3 == index;
                    if (shouldLoadMore) {
                      _loadMore();
                    }
                    return ListActivityItem(
                      activity: activities[index],
                      feedGroup: _feedGroup,
                    );
                  }
                )
              );
            }
          ),
          Expanded(
            // This will make the GridView take up all remaining space
            child: savedImages.isEmpty
                ? Center(
                    child: Text(
                      "No images saved.",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // Number of columns in the grid
                      crossAxisSpacing: 5, // Spacing between the columns
                      mainAxisSpacing: 5, // Spacing between the rows
                    ),
                    itemCount: savedImages.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Container(
                        decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(8), // Rounded corners
                            border: Border.all(
                                color:
                                    Colors.grey[400]!) // Border around each box
                            ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: savedImages[index],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        child: Row(
          children: [
            Expanded(
              child: GNav(
                color: Colors.black,
                activeColor: Colors.black,
                onTabChange: (index) {
                  if (index == 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SearchPage(),
                      ),
                    );
                  }
                },
                tabs: const [
                  GButton(icon: LineIcons.globe),
                  GButton(icon: LineIcons.search),
                  GButton(icon: LineIcons.user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
