import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_typeahead/flutter_typeahead.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '涼みスポットマップ',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  List<Marker> markers = [];
  LatLng currentLocation = LatLng(35.6895, 139.6917); // デフォルト位置：東京
  TextEditingController searchController = TextEditingController();

  // 東京23区のリスト
  final List<String> tokyo23Wards = [
    '千代田区',
    '中央区',
    '港区',
    '新宿区',
    '文京区',
    '台東区',
    '墨田区',
    '江東区',
    '品川区',
    '目黒区',
    '大田区',
    '世田谷区',
    '渋谷区',
    '中野区',
    '杉並区',
    '豊島区',
    '北区',
    '荒川区',
    '板橋区',
    '練馬区',
    '足立区',
    '葛飾区',
    '江戸川区'
  ];

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
    loadCoolSpots();
  }

  void getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        mapController.move(currentLocation, 13);
      });
      loadNearbySpots();
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  void loadCoolSpots() async {
    // GeoJSONファイルを読み込み、マーカーを作成する処理
    // この部分は実際のGeoJSONファイルの構造に合わせて実装する必要があります
  }

  void loadNearbySpots() {
    // 現在地から500m以内のスポットをフィルタリングする処理
  }


  List<String> getSuggestions(String query) {
    return tokyo23Wards
        .where((ward) => ward.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
  
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> moveToArea(String areaName) async {
    final String overpassUrl = 'https://overpass-api.de/api/interpreter';
    final String overpassQuery = '''
      [out:json];
      area["name" = "$areaName"];
      node(pivot);
      out center;
    ''';

    try {
      final response = await http.post(Uri.parse(overpassUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'data': overpassQuery});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Overpass API Response: $data');

        if (data['elements'].isNotEmpty) {
          final center = data['elements'][0]['center'];
          LatLng newCenter = LatLng(center['lat'], center['lon']);
          mapController.move(newCenter, 13);
          setState(() {
            currentLocation = newCenter;
            // マーカーを更新
            markers = [
              Marker(
                width: 80.0,
                height: 80.0,
                point: newCenter,
                builder: (ctx) => Column(
                  children: [
                    Icon(Icons.location_on, color: Colors.red, size: 40),
                    Container(
                      padding: EdgeInsets.all(4),
                      color: Colors.white,
                      child: Text(areaName,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ];
          });
          loadNearbySpots();
        } else {
          showErrorSnackBar('エリアが見つかりませんでした');
        }
      } else {
        showErrorSnackBar('データの読み込みに失敗しました');
      }
    } catch (e) {
      showErrorSnackBar('エラーが発生しました: $e');
    }
  }

  

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('涼みスポットマップ'),
    ),
    body: Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: TypeAheadField<String>(
            textFieldConfiguration: TextFieldConfiguration(
              controller: searchController,
              decoration: InputDecoration(
                hintText: '東京23区を入力',
                suffixIcon: Icon(Icons.search),
              ),
            ),
            suggestionsCallback: (pattern) async {
              return getSuggestions(pattern);
            },
            itemBuilder: (context, suggestion) {
              return ListTile(
                title: Text(suggestion),
              );
            },
            onSuggestionSelected: (suggestion) {
              searchController.text = suggestion;
              moveToArea(suggestion);
            },
          ),
        ),
        Expanded(
          child: FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: currentLocation,
              zoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
      ],
    ),
  );
}
}