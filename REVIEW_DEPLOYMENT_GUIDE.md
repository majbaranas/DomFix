# 🚀 REVIEW SYSTEM - QUICK DEPLOYMENT GUIDE

## Prerequisites
- Firebase CLI installed (`npm install -g firebase-tools`)
- Firebase project configured
- Already authenticated (`firebase login`)

---

## 📦 STEP 1: Deploy Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions:aggregateTechnicianReview,functions:updateCompletedJobsCount
```

Expected output:
```
✔  functions[aggregateTechnicianReview(us-central1)] Successful create operation.
✔  functions[updateCompletedJobsCount(us-central1)] Successful create operation.
Deploy complete!
```

---

## 🔥 STEP 2: Update Firestore Rules

```bash
firebase deploy --only firestore:rules
```

Rules already include review security (in `firestore.rules`).

---

## 📱 STEP 3: Test the Flow

### As Technician:
1. Open DomFix app as technician
2. Accept a pending booking
3. Progress through: `accepted` → `on_the_way` → `arrived` → `in_progress`
4. Tap "Complete" button
5. **New:** Upload 1-2 photos of completed work
6. Tap "Finish Job"
7. Status becomes `completed`

### As Client:
1. Open DomFix app as client (same booking)
2. **Review modal should appear automatically** within a few seconds
3. Rate the technician (1-5 stars)
4. Write an optional review comment
5. Tap "Submit Review"
6. Done!

### Verify in Firestore Console:
1. Go to Firebase Console → Firestore Database
2. Check `reviews/{bookingId}` - should have new review document
3. Check `technician_stats/{technicianId}` - should have updated stats
4. Check `users/{technicianId}` - should show synced rating/reviewCount
5. Check `completed_job_photos` - should show uploaded photos

---

## 🏆 STEP 4: Verify Ranking Works

1. Open map view as client
2. Nearby technicians should be sorted by `rankScore`
3. Top-rated technicians appear first
4. Technicians with 0 reviews appear last

---

## ✅ Success Criteria

- [ ] Cloud Functions deployed successfully
- [ ] Review modal appears after job completion
- [ ] Reviews save to Firestore
- [ ] `technician_stats` updates automatically
- [ ] Photos upload to Storage
- [ ] Technician profile shows real data
- [ ] Map ranking works (top technicians first)

---

## 🐛 Troubleshooting

### Review modal doesn't appear?
- Check `ReviewPromptService` is initialized in `main_layout.dart`
- Verify booking status is exactly `'completed'`
- Check browser/app console for errors

### Cloud Function not triggering?
- Check Firebase Functions logs: `firebase functions:log`
- Verify function deployed: `firebase functions:list`
- Check Firestore rules allow review creation

### Photos not uploading?
- Verify Firebase Storage rules allow writes
- Check Storage bucket is configured
- Add `image_picker` dependency if missing

---

## 📝 Quick Test Commands

```bash
# View function logs
firebase functions:log --only aggregateTechnicianReview

# Check deployed functions
firebase functions:list

# Re-deploy specific function
firebase deploy --only functions:aggregateTechnicianReview
```

---

## 🎉 You're Done!

The review system is now live and production-ready. Technicians will start building reputation, and clients can leave feedback after every job.

**Next Steps:**
- Monitor Cloud Functions usage in Firebase Console
- Track review submission rate
- Analyze technician rankings
- Consider adding badges/achievements for top performers
