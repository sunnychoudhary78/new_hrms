import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipPath(
          clipper: BottomCurveClipper(),
          child: Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppColors.softHeroGradient,
              border: Border(
                bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
              ),
            ),
          ),
        ),
        Positioned(top: 36, left: -24, child: _bubble(100)),
        Positioned(top: 100, right: 20, child: _bubble(72)),
        Positioned(
          top: 24,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.card, width: 4),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.softBlueMid,
                      backgroundImage: imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : const AssetImage('assets/images/profile.jpg')
                                as ImageProvider,
                    ),
                  ),
                  GestureDetector(
                    onTap: onEditTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm + 6),
              Text(
                name,
                style: TextStyle(
                  color: AppColors.title,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 4,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  empId,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.06),
      ),
    );
  }
}
