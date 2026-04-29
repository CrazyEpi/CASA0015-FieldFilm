import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationService {
  static Future<Map<String, String>> getEnvironmentData() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled. Please turn on GPS.");
      }

      // Check location permissions
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Ask for permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Denied
          throw Exception("Location permissions are denied by user.");
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        // User denied permissions permanently, we cannot request permissions.
        throw Exception("Location permissions are permanently denied. Please enable them in app settings.");
      }

      // Functions
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      String addressStr = "Unknown Area";
      
      // Query location
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          String city = placemarks.first.locality ?? "";
          String area = placemarks.first.subLocality ?? "";
          
          if (city.isNotEmpty && area.isNotEmpty) {
            addressStr = '$city, $area';
          } else if (city.isNotEmpty) {
            addressStr = city;
          } else if (area.isNotEmpty) {
            addressStr = area;
          }
        }
      } catch (e) {
        print("[LocationService] Native geocoding error: $e");
      }

      String weatherInfo = "";
      try {
        final apiKey = dotenv.env['WEATHER_API_KEY'];
        if (apiKey == null || apiKey.isEmpty) {
          weatherInfo = "Missing API Key";
          print("[LocationService] Weather fetch failed: $weatherInfo");
        } else {
          final url = 'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric';
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
          
          if (res.statusCode == 200) {
            final weatherData = jsonDecode(res.body);
            weatherInfo = '${weatherData['weather'][0]['main']}, ${weatherData['main']['temp']}°C';
            
            // If address query failed, use city name from weather API
            if (addressStr == "Unknown Area") {
              String apiCity = weatherData['name'] ?? "";
              if (apiCity.isNotEmpty) {
                addressStr = apiCity;
                print("[LocationService] Fallback to OpenWeather city: $apiCity");
              }
            }
            
          } else {
            if (res.statusCode == 401) {
              weatherInfo = "API Key Invalid";
            } else if (res.statusCode == 404) {
              weatherInfo = "Location Not Found";
            } else if (res.statusCode == 429) {
              weatherInfo = "API Rate Limit Exceeded";
            } else {
              weatherInfo = "Unknown: ${res.statusCode}";
            }
            print("[LocationService] Weather fetch failed: HTTP ${res.statusCode} - $weatherInfo");
          }
        }
      } on TimeoutException catch (e) {
        weatherInfo = "Connection Timeout";
        print("[LocationService] Weather connection timeout: $e");
      } on SocketException catch (e) {
        weatherInfo = "No Internet Connection";
        print("[LocationService] Weather socket exception (No Internet): $e");
      } catch (e) {
        weatherInfo = "Unknown Error: ${e.toString().split('\n')[0]}";
        print("[LocationService] Weather unknown error: $e");
      }

      return {
        'location': '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        'address': addressStr,
        'alt': '${position.altitude.toStringAsFixed(1)}m',
        'weather': weatherInfo,
      };
    } catch (e) {
      print("[LocationService] Hardware error: $e");
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}