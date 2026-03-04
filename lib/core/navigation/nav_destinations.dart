import 'package:flutter/material.dart';

import 'app_routes.dart';

/// Data class for navigation destinations.
class NavItem {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
}

/// Side rail destinations (full set, 9 items).
const List<NavItem> sideDestinations = [
  NavItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
    route: AppRoutes.home,
  ),
  NavItem(
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    label: 'Search',
    route: AppRoutes.customSearch,
  ),
  NavItem(
    icon: Icons.live_tv_outlined,
    selectedIcon: Icons.live_tv,
    label: 'Live TV',
    route: AppRoutes.tv,
  ),
  NavItem(
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
    label: 'Guide',
    route: AppRoutes.epg,
  ),
  NavItem(
    icon: Icons.movie_outlined,
    selectedIcon: Icons.movie,
    label: 'Movies',
    route: AppRoutes.vod,
  ),
  NavItem(
    icon: Icons.tv_outlined,
    selectedIcon: Icons.tv,
    label: 'Series',
    route: AppRoutes.series,
  ),
  NavItem(
    icon: Icons.video_library_outlined,
    selectedIcon: Icons.video_library,
    label: 'DVR',
    route: AppRoutes.dvr,
  ),
  NavItem(
    icon: Icons.favorite_outline,
    selectedIcon: Icons.favorite,
    label: 'Favorites',
    route: AppRoutes.favorites,
  ),
  NavItem(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: 'Settings',
    route: AppRoutes.settings,
  ),
];

/// Bottom bar destinations (compact, max 5 items).
const List<NavItem> bottomDestinations = [
  NavItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
    route: AppRoutes.home,
  ),
  NavItem(
    icon: Icons.live_tv_outlined,
    selectedIcon: Icons.live_tv,
    label: 'Live TV',
    route: AppRoutes.tv,
  ),
  NavItem(
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    label: 'Search',
    route: AppRoutes.customSearch,
  ),
  NavItem(
    icon: Icons.movie_outlined,
    selectedIcon: Icons.movie,
    label: 'Movies',
    route: AppRoutes.vod,
  ),
  NavItem(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: 'Settings',
    route: AppRoutes.settings,
  ),
];
