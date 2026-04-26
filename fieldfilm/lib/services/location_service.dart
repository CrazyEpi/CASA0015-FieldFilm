import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationService {
  
  // Collects GPS coordinates, street address, and weather info.
  static Future<Map<String, String>> getEnvironmentData() async {
    try {
      // --- Physical Location ---
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // --- Reverse Geocoding ---
      String addressStr = "Unknown Area";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          addressStr = '${place.locality ?? "City"}, ${place.subLocality ?? "Area"}';
        }
      } catch (e) {
        print("[LocationService] Geocoding error: $e");
      }

      // --- Weather API Integration ---
      String weatherInfo = "Weather unavailable";
      try {
        final apiKey = dotenv.env['WEATHER_API_KEY'];
        final url = 'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric';
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        
        if (res.statusCode == 200) {
          final weatherData = jsonDecode(res.body);
          weatherInfo = '${weatherData['weather'][0]['main']}, ${weatherData['main']['temp']}°C';
        }
      } catch (e) {
        print("[LocationService] Weather API error: $e");
      }

      return {
        'location': '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        'address': addressStr,
        'alt': '${position.altitude.toStringAsFixed(1)}m',
        'weather': weatherInfo,
      };
      
    } catch (e) {
      print("[LocationService] Hardware error: $e");
      throw Exception("GPS error. Check device permissions.");
    }
  }
}