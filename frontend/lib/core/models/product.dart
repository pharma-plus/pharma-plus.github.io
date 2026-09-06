import 'package:flutter/material.dart';

import '../widgets/product_art.dart';

/// ============================================================
/// MODÈLE PRODUIT — architecture partagée (POS, panier, catalogue).
/// Chaque produit possède SA PROPRE image : [image] (asset ou URL
/// http(s)) est prioritaire ; à défaut, la miniature 3D peinte
/// [art] est utilisée comme fallback propre et léger (web-safe).
/// Les vraies données restent servies par le backend (Supabase) ;
/// ce modèle ne fait que porter l'affichage.
/// ============================================================
class Product {
  final String id;
  final String name;
  final String subtitle; // labo · forme · description courte
  final String category;
  final double price;
  final int stock;
  final int qty;
  final Color tint;
  final String? image;
  final ProductArt art;

  const Product({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.category,
    required this.price,
    required this.stock,
    this.qty = 1,
    required this.tint,
    this.image,
    this.art = ProductArt.generic,
  });

  Product copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? category,
    double? price,
    int? stock,
    int? qty,
    Color? tint,
    String? image,
    ProductArt? art,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        subtitle: subtitle ?? this.subtitle,
        category: category ?? this.category,
        price: price ?? this.price,
        stock: stock ?? this.stock,
        qty: qty ?? this.qty,
        tint: tint ?? this.tint,
        image: image ?? this.image,
        art: art ?? this.art,
      );
}
