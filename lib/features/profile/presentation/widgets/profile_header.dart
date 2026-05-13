import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/features/profile/presentation/widgets/curve_clipper.dart';

class CurvedProfileHeader extends StatelessWidget {
  final String name;
  final String empId;
  final String imageUrl;
  final VoidCallback onEditTap;

  const CurvedProfileHeader({
    super.key,
    required this.name,
    required this.empId,
    required this.imageUrl,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final blurSigma = isIOS ? 10.0 : 12.0;

    return Stack(
      children: [
        /// GLASS CURVED HEADER
        ClipPath(
          clipper: BottomCurveClipper(),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(.85),

                border: Border(
                  bottom: BorderSide(color: scheme.outline.withOpacity(.15)),
                ),
              ),
            ),
          ),
        ),

        /// SOFT FLOATING BUBBLES (subtle)
        Positioned(top: 40, left: -20, child: _bubble(context, 120)),

        Positioned(top: 120, right: 30, child: _bubble(context, 100)),

        Positioned(top: -80, right: -70, child: _bubble(context, 180)),

        /// PROFILE CONTENT
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              children: [
                /// FLOATING AVATAR WITH GLASS EFFECT
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,

                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withOpacity(isIOS ? .14 : .25),
                            blurRadius: isIOS ? 16 : 24,
                            offset: Offset(0, isIOS ? 8 : 10),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 46,

                        backgroundColor: scheme.surface.withOpacity(.6),

                        backgroundImage: imageUrl.isNotEmpty
                            ? NetworkImage(imageUrl)
                            : const AssetImage('assets/images/profile.jpg')
                                  as ImageProvider,
                      ),
                    ),

                    /// EDIT BUTTON (premium glass style)
                    GestureDetector(
                      onTap: onEditTap,
                      child: Container(
                        padding: const EdgeInsets.all(7),

                        decoration: BoxDecoration(
                          color: scheme.surface.withOpacity(.9),

                          shape: BoxShape.circle,

                          border: Border.all(
                            color: scheme.outline.withOpacity(.2),
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withOpacity(
                                isIOS ? .12 : .2,
                              ),
                              blurRadius: isIOS ? 8 : 10,
                            ),
                          ],
                        ),

                        child: Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                /// NAME
                Text(
                  name,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                  ),
                ),

                const SizedBox(height: 4),

                /// EMPLOYEE ID
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),

                  decoration: BoxDecoration(
                    color: scheme.surface.withOpacity(.5),
                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Text(
                    empId,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// SUBTLE BACKGROUND BUBBLES
  Widget _bubble(BuildContext context, double size) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,

      decoration: BoxDecoration(
        shape: BoxShape.circle,

        color: scheme.onPrimaryContainer.withOpacity(.06),
      ),
    );
  }
}
