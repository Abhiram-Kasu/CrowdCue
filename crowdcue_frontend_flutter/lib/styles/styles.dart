import 'package:flutter/material.dart';

// Define your base primary color. Change this to update both themes.
const Color primaryColorBase = Color(0xFF16EBF2); // A nice Apple-like blue

// Define a slightly different shade for dark mode if desired.
// For example, a slightly desaturated or lighter version for dark backgrounds.
const Color primaryColorDarkVariant = Color(
  0xFF178B8F,
); // A slightly brighter blue for dark mode

// --- Light Theme ---
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: primaryColorBase,
  colorScheme: ColorScheme.light(
    primary: primaryColorBase,
    secondary: primaryColorBase, // Often, secondary is the same or a complement
    surface: Colors.white,
    error: Colors.red,
    onPrimary: Colors.white, // Text/icon color on primary color
    onSecondary: Colors.white, // Text/icon color on secondary color
    onSurface: Colors.black, // Text/icon color on surface color

    onError: Colors.white, // Text/icon color on error color
  ),
  scaffoldBackgroundColor: const Color(0xFFF2F2F7),
  appBarTheme: AppBarTheme(
    color: const Color(0xFFF2F2F7),
    iconTheme: const IconThemeData(color: Colors.white),
    toolbarTextStyle: const TextTheme(
      titleLarge: TextStyle(
        color: Colors.black,
        fontSize: 30,
        letterSpacing: 5,

        fontWeight: FontWeight.bold,
      ),
    ).bodyMedium,
    titleTextStyle: const TextTheme(
      titleLarge: TextStyle(
        color: Colors.black,
        fontSize: 30,
        letterSpacing: 5,
        fontWeight: FontWeight.bold,
      ),
    ).titleLarge,
  ),
  buttonTheme: ButtonThemeData(
    buttonColor: primaryColorBase,
    textTheme: ButtonTextTheme.primary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      shadowColor: primaryColorBase,
      elevation: 10,
      backgroundColor: primaryColorBase,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: primaryColorBase,
    foregroundColor: Colors.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: primaryColorBase, width: 2.0),
      borderRadius: BorderRadius.circular(8.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
      borderRadius: BorderRadius.circular(8.0),
    ),
    labelStyle: TextStyle(color: primaryColorBase),
  ),
  // Add other theme properties as needed
);

// --- Dark Theme ---
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: primaryColorDarkVariant,
  colorScheme: ColorScheme.dark(
    primary: primaryColorDarkVariant,
    secondary: primaryColorDarkVariant,
    surface: const Color(0xFF1C1C1E), // A dark grey surface

    error: Colors.redAccent,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white,

    onError: Colors.black,
  ),
  scaffoldBackgroundColor: Colors.black,
  appBarTheme: AppBarTheme(
    color: Colors.black, // Darker app bar
    iconTheme: IconThemeData(color: primaryColorDarkVariant),
    toolbarTextStyle: TextTheme(
      titleLarge: TextStyle(
        color: Colors.white,
        fontSize: 30,
        letterSpacing: 5,
        fontWeight: FontWeight.bold,
      ),
    ).bodyMedium,
    titleTextStyle: TextTheme(
      titleLarge: TextStyle(
        color: Colors.white,
        fontSize: 30,
        letterSpacing: 5,
        fontWeight: FontWeight.bold,
      ),
    ).titleLarge,
  ),
  buttonTheme: ButtonThemeData(
    buttonColor: primaryColorDarkVariant,
    textTheme: ButtonTextTheme.primary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColorDarkVariant,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: primaryColorDarkVariant,
    foregroundColor: Colors.black,
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: primaryColorDarkVariant, width: 2.0),
      borderRadius: BorderRadius.circular(8.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade700, width: 1.0),
      borderRadius: BorderRadius.circular(8.0),
    ),
    labelStyle: TextStyle(color: primaryColorDarkVariant),
    hintStyle: TextStyle(color: Colors.grey.shade500),
  ),
  // Add other theme properties as needed
);

/*
let spotifyGreen: Color = Color(red: 29/255.0, green: 185/255.0, blue: 84/255.0)
    let spotifyBlack: Color = Color(red: 25/255.0, green: 20/255.0, blue: 20/255.0)
*/

const spotifyGreen = Color.fromARGB(255, 29, 185, 84);
const spotifyBlack = Color.fromARGB(255, 25, 20, 20);
