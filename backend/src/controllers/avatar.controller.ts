import { Request, Response, NextFunction } from 'express';
import path from 'path';
import fs from 'fs';
import multer from 'multer';
import { pool } from '../config/db';
import { ApiError } from '../utils/apiError';
import { ok } from '../utils/response';

const uploadDir = path.join(__dirname, '..', '..', 'uploads', 'avatars');
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const userId = req.user?.id ?? 'anon';
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `user_${userId}_${Date.now()}${ext}`);
  },
});

const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif']);

const rawAvatarUpload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, 
  fileFilter: (_req, file, cb) => {
    if (!ALLOWED_MIME.has(file.mimetype)) {
      cb(new Error('Only JPG, PNG, WEBP, or GIF images are allowed'));
      return;
    }
    cb(null, true);
  },
}).single('avatar');

export function avatarUpload(req: Request, res: Response, next: NextFunction) {
  rawAvatarUpload(req, res, (err: unknown) => {
    if (!err) return next();
    if (err instanceof multer.MulterError) {
      const msg = err.code === 'LIMIT_FILE_SIZE' ? 'Image must be 5MB or smaller' : err.message;
      return next(new ApiError(400, msg));
    }
    return next(new ApiError(400, err instanceof Error ? err.message : 'Invalid upload'));
  });
}

export const avatarController = {
  async upload(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthorized');
      if (!req.file) throw new ApiError(400, 'No image file was uploaded (field name must be "avatar")');

      const relativeUrl = `/uploads/avatars/${req.file.filename}`;
      const fullUrl = `${req.protocol}://${req.get('host')}${relativeUrl}`;

      const [prevRows] = await pool.query('SELECT avatar_url FROM users WHERE id = ?', [req.user.id]);
      await pool.query('UPDATE users SET avatar_url = ? WHERE id = ?', [fullUrl, req.user.id]);

      const prev = (prevRows as { avatar_url?: string }[])[0]?.avatar_url;
      if (prev && prev.includes('/uploads/avatars/')) {
        const prevFilename = prev.split('/uploads/avatars/')[1];
        if (prevFilename) {
          const prevPath = path.join(uploadDir, prevFilename);
          fs.unlink(prevPath, () => {  });
        }
      }

      return ok(res, { avatar_url: fullUrl }, 'Avatar updated');
    } catch (e) {
      next(e);
    }
  },
};