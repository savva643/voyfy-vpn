import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DraggableSearchableListView extends StatefulWidget {
  const DraggableSearchableListView({
     Key? key,
  }) : super(key: key);

  @override
  _DraggableSearchableListViewState createState() =>
      _DraggableSearchableListViewState();
}

class _DraggableSearchableListViewState
    extends State<DraggableSearchableListView> {
  final TextEditingController searchTextController = TextEditingController();
  final ValueNotifier<bool> searchTextCloseButtonVisibility =
  ValueNotifier<bool>(false);
  final ValueNotifier<bool> searchFieldVisibility = ValueNotifier<bool>(false);
  @override
  void dispose() {
    searchTextController.dispose();
    searchTextCloseButtonVisibility.dispose();
    searchFieldVisibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent == 1.0) {
          searchFieldVisibility.value = true;
        } else {
          searchFieldVisibility.value = false;
        }
        return true;
      },
      child: DraggableScrollableActuator(
        child: Stack(
          children: <Widget>[
            DraggableScrollableSheet(
              initialChildSize: 0.30,
              minChildSize: 0.15,
              maxChildSize: 1.0,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16.0),
                      topRight: Radius.circular(16.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey,
                          offset: Offset(1.0, -2.0),
                          blurRadius: 4.0,
                          spreadRadius: 2.0)
                    ],
                  ),
                  child: ListView.builder(
                    controller: scrollController,

                    ///we have 25 rows plus one header row.
                    itemCount: 25 + 1,
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return Container(
                          child: Column(
                            children: <Widget>[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: 16.0,
                                    left: 24.0,
                                    right: 24.0,
                                  ),
                                  child: Text(
                                    "Favorites",
                                    style:
                                    Theme.of(context).textTheme.headline6,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 8.0,
                              ),
                              Divider(color: Colors.grey),
                            ],
                          ),
                        );
                      }
                      return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: ListTile(title: Text('Item $index')));
                    },
                  ),
                );
              },
            ),
            Positioned(
              left: 0.0,
              top: 0.0,
              right: 0.0,
              child: ValueListenableBuilder<bool>(
                  valueListenable: searchFieldVisibility,
                  builder: (context, value, child) {
                    return value
                        ? PreferredSize(
                      preferredSize: Size.fromHeight(56.0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                width: 1.0,
                                color: Theme.of(context).dividerColor),
                          ),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    )
                        : Container();
                  }),
            ),
          ],
        ),
      ),
    );
  }
}